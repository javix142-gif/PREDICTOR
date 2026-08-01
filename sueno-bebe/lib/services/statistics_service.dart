import 'dart:math' as math;

import 'package:timezone/timezone.dart' as tz;

import '../models/sleep_event.dart';
import '../models/sleep_prediction.dart';
import '../models/sleep_statistics.dart';
import '../utils/stat_math.dart';

class AwakeWindowObservation {
  const AwakeWindowObservation({
    required this.startUtc,
    required this.endUtc,
    required this.minutes,
    required this.nextSleepType,
    required this.nextSleepAccuracy,
    required this.sleepSequenceNumber,
  });

  final DateTime startUtc;
  final DateTime endUtc;
  final double minutes;
  final SleepType nextSleepType;
  final SleepAccuracy nextSleepAccuracy;
  final int sleepSequenceNumber;
}

class StatisticsService {
  const StatisticsService();

  Duration clippedDuration({
    required SleepEvent event,
    required DateTime intervalStartUtc,
    required DateTime intervalEndUtc,
    required DateTime nowUtc,
  }) {
    final DateTime eventStart = event.startUtc.toUtc();
    final DateTime eventEnd = (event.endUtc ?? nowUtc).toUtc();
    final DateTime start = eventStart.isAfter(intervalStartUtc)
        ? eventStart
        : intervalStartUtc.toUtc();
    final DateTime end = eventEnd.isBefore(intervalEndUtc)
        ? eventEnd
        : intervalEndUtc.toUtc();
    return end.isAfter(start) ? end.difference(start) : Duration.zero;
  }

  double rollingSleepMinutes({
    required Iterable<SleepEvent> events,
    required DateTime nowUtc,
    Duration window = const Duration(hours: 24),
  }) {
    final DateTime end = nowUtc.toUtc();
    final DateTime start = end.subtract(window);
    return events.fold<double>(0, (double total, SleepEvent event) {
      return total +
          clippedDuration(
            event: event,
            intervalStartUtc: start,
            intervalEndUtc: end,
            nowUtc: end,
          ).inSeconds /
              60;
    });
  }

  SleepStatistics calculate({
    required Iterable<SleepEvent> events,
    required Iterable<SleepPrediction> predictions,
    required Duration period,
    required DateTime nowUtc,
    required tz.Location location,
  }) {
    final DateTime endUtc = nowUtc.toUtc();
    final DateTime startUtc = endUtc.subtract(period);
    final List<SleepEvent> sortedEvents = events.toList()
      ..sort((SleepEvent a, SleepEvent b) => a.startUtc.compareTo(b.startUtc));
    final List<_EventSlice> slices = <_EventSlice>[];
    for (final SleepEvent event in sortedEvents) {
      final DateTime effectiveEnd = (event.endUtc ?? endUtc).toUtc();
      final DateTime sliceStart = event.startUtc.isAfter(startUtc)
          ? event.startUtc.toUtc()
          : startUtc;
      final DateTime sliceEnd = effectiveEnd.isBefore(endUtc)
          ? effectiveEnd
          : endUtc;
      if (sliceEnd.isAfter(sliceStart)) {
        slices.add(
          _EventSlice(event: event, startUtc: sliceStart, endUtc: sliceEnd),
        );
      }
    }

    final double totalMinutes = slices.fold<double>(
      0,
      (double sum, _EventSlice slice) => sum + slice.minutes,
    );
    final double dayMinutes = slices
        .where((_EventSlice slice) => slice.event.type == SleepType.nap)
        .fold<double>(0, (double sum, _EventSlice slice) => sum + slice.minutes);
    final double nightMinutes = totalMinutes - dayMinutes;

    final List<double> napDurations = slices
        .where((_EventSlice slice) => slice.event.type == SleepType.nap)
        .map((_EventSlice slice) => slice.minutes)
        .toList(growable: false);

    final List<double> continuousDurations =
        slices.map((_EventSlice slice) => slice.minutes).toList();

    final List<AwakeWindowObservation> awakeObservations = buildAwakeWindows(
      events: sortedEvents,
      nowUtc: endUtc,
      location: location,
    ).where((AwakeWindowObservation item) {
      return !item.endUtc.isBefore(startUtc) && !item.endUtc.isAfter(endUtc);
    }).toList(growable: false);
    final List<double> awakeMinutes = awakeObservations
        .map((AwakeWindowObservation item) => item.minutes)
        .toList(growable: false);

    final List<double> nightStartMinutes = <double>[];
    final List<double> wakeMinutes = <double>[];
    for (final SleepEvent event in sortedEvents) {
      if (event.type != SleepType.night || event.endUtc == null) {
        continue;
      }
      if (event.endUtc!.isBefore(startUtc) || event.startUtc.isAfter(endUtc)) {
        continue;
      }
      final tz.TZDateTime localStart =
          tz.TZDateTime.from(event.startUtc, location);
      final tz.TZDateTime localEnd = tz.TZDateTime.from(event.endUtc!, location);
      double startMinute = localStart.hour * 60 + localStart.minute.toDouble();
      if (startMinute < 12 * 60) {
        startMinute += 24 * 60;
      }
      nightStartMinutes.add(startMinute);
      wakeMinutes.add(localEnd.hour * 60 + localEnd.minute.toDouble());
    }

    final List<DailySleepTotal> dailyTotals = _buildDailyTotals(
      slices: slices,
      startUtc: startUtc,
      endUtc: endUtc,
      location: location,
    );
    final List<double> totalsPerDay = dailyTotals
        .map((DailySleepTotal item) => item.totalMinutes)
        .toList(growable: false);

    final List<double> predictionErrors = predictions
        .where((SleepPrediction prediction) {
          final DateTime? evaluated = prediction.evaluatedAtUtc;
          return evaluated != null &&
              !evaluated.isBefore(startUtc) &&
              !evaluated.isAfter(endUtc) &&
              prediction.errorMinutes != null;
        })
        .map((SleepPrediction prediction) => prediction.errorMinutes!.toDouble())
        .toList(growable: false);

    return SleepStatistics(
      periodStartUtc: startUtc,
      periodEndUtc: endUtc,
      totalMinutes: totalMinutes,
      dayMinutes: dayMinutes,
      nightMinutes: nightMinutes,
      napCount: napDurations.length,
      averageNapMinutes: StatMath.average(napDurations),
      medianNapMinutes: StatMath.median(napDurations),
      shortestNapMinutes:
          napDurations.isEmpty ? null : napDurations.reduce(math.min),
      longestNapMinutes:
          napDurations.isEmpty ? null : napDurations.reduce(math.max),
      longestContinuousSleepMinutes: continuousDurations.isEmpty
          ? null
          : continuousDurations.reduce(math.max),
      medianNightStartMinuteOfDay:
          _normalizeMinuteOfDay(StatMath.median(nightStartMinutes)),
      medianWakeMinuteOfDay: StatMath.median(wakeMinutes),
      medianAwakeWindowMinutes: StatMath.median(awakeMinutes),
      minimumAwakeWindowMinutes:
          awakeMinutes.isEmpty ? null : awakeMinutes.reduce(math.min),
      maximumAwakeWindowMinutes:
          awakeMinutes.isEmpty ? null : awakeMinutes.reduce(math.max),
      awakeWindowIqrMinutes: StatMath.interquartileRange(awakeMinutes),
      dailyVariabilityMinutes: StatMath.standardDeviation(totalsPerDay),
      evaluablePredictionCount: predictionErrors.length,
      medianPredictionErrorMinutes: StatMath.median(predictionErrors),
      dailyTotals: dailyTotals,
      napDurationsMinutes: napDurations,
      awakeWindowsMinutes: awakeMinutes,
    );
  }

  List<AwakeWindowObservation> buildAwakeWindows({
    required Iterable<SleepEvent> events,
    required DateTime nowUtc,
    required tz.Location location,
  }) {
    final List<SleepEvent> completed = events
        .where((SleepEvent event) => event.endUtc != null)
        .toList()
      ..sort((SleepEvent a, SleepEvent b) => a.startUtc.compareTo(b.startUtc));
    final List<AwakeWindowObservation> observations =
        <AwakeWindowObservation>[];
    for (int index = 0; index < completed.length - 1; index += 1) {
      final SleepEvent previous = completed[index];
      final SleepEvent next = completed[index + 1];
      final DateTime wake = previous.endUtc!.toUtc();
      if (!next.startUtc.isAfter(wake) || next.startUtc.isAfter(nowUtc)) {
        continue;
      }
      final double minutes = next.startUtc.difference(wake).inSeconds / 60;
      if (minutes < 10 || minutes > 12 * 60) {
        continue;
      }
      observations.add(
        AwakeWindowObservation(
          startUtc: wake,
          endUtc: next.startUtc,
          minutes: minutes,
          nextSleepType: next.type,
          nextSleepAccuracy: next.accuracy,
          sleepSequenceNumber: _sequenceForEvent(next, completed, location),
        ),
      );
    }
    return observations;
  }

  int _sequenceForEvent(
    SleepEvent target,
    List<SleepEvent> events,
    tz.Location location,
  ) {
    final tz.TZDateTime targetLocal =
        tz.TZDateTime.from(target.startUtc, location);
    return events.where((SleepEvent event) {
          final tz.TZDateTime local =
              tz.TZDateTime.from(event.startUtc, location);
          return local.year == targetLocal.year &&
              local.month == targetLocal.month &&
              local.day == targetLocal.day &&
              !event.startUtc.isAfter(target.startUtc);
        }).length;
  }

  List<DailySleepTotal> _buildDailyTotals({
    required List<_EventSlice> slices,
    required DateTime startUtc,
    required DateTime endUtc,
    required tz.Location location,
  }) {
    final tz.TZDateTime localStart = tz.TZDateTime.from(startUtc, location);
    final tz.TZDateTime localEnd = tz.TZDateTime.from(endUtc, location);
    tz.TZDateTime day = tz.TZDateTime(
      location,
      localStart.year,
      localStart.month,
      localStart.day,
    );
    final List<DailySleepTotal> result = <DailySleepTotal>[];
    while (!day.isAfter(localEnd)) {
      final tz.TZDateTime nextDay = tz.TZDateTime(
        location,
        day.year,
        day.month,
        day.day + 1,
      );
      double nap = 0;
      double night = 0;
      for (final _EventSlice slice in slices) {
        final DateTime clippedStart = slice.startUtc.isAfter(day.toUtc())
            ? slice.startUtc
            : day.toUtc();
        final DateTime clippedEnd = slice.endUtc.isBefore(nextDay.toUtc())
            ? slice.endUtc
            : nextDay.toUtc();
        if (!clippedEnd.isAfter(clippedStart)) {
          continue;
        }
        final double minutes = clippedEnd.difference(clippedStart).inSeconds / 60;
        if (slice.event.type == SleepType.nap) {
          nap += minutes;
        } else {
          night += minutes;
        }
      }
      result.add(
        DailySleepTotal(
          localDate: DateTime(day.year, day.month, day.day),
          totalMinutes: nap + night,
          dayMinutes: nap,
          nightMinutes: night,
        ),
      );
      day = nextDay;
    }
    return result;
  }

  double? _normalizeMinuteOfDay(double? value) {
    if (value == null) {
      return null;
    }
    return value % (24 * 60);
  }
}

class _EventSlice {
  const _EventSlice({
    required this.event,
    required this.startUtc,
    required this.endUtc,
  });

  final SleepEvent event;
  final DateTime startUtc;
  final DateTime endUtc;

  double get minutes => endUtc.difference(startUtc).inSeconds / 60;
}
