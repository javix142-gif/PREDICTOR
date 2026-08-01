import 'dart:convert';
import 'dart:math' as math;

import 'package:timezone/timezone.dart' as tz;

import '../constants/sleep_reference_ranges.dart';
import '../models/baby_profile.dart';
import '../models/sleep_event.dart';
import '../models/sleep_prediction.dart';
import '../utils/date_time_utils.dart';
import '../utils/stat_math.dart';
import 'statistics_service.dart';

class PredictionService {
  const PredictionService({StatisticsService? statisticsService})
      : _statisticsService = statisticsService ?? const StatisticsService();

  static const String algorithmVersion = 'sleep-window-v1';
  static const Duration historyWindow = Duration(days: 14);
  static const Duration minimumIntervalWidth = Duration(minutes: 20);

  final StatisticsService _statisticsService;

  SleepPrediction createPrediction({
    required String id,
    required BabyProfile profile,
    required Iterable<SleepEvent> events,
    required DateTime nowUtc,
    required tz.Location location,
  }) {
    final List<SleepEvent> sorted = events.toList()
      ..sort((SleepEvent a, SleepEvent b) => a.startUtc.compareTo(b.startUtc));
    final SleepEvent? lastCompleted = _lastCompleted(sorted);
    if (lastCompleted == null || lastCompleted.endUtc == null) {
      throw StateError(
        'Se necesita al menos un despertar registrado para predecir.',
      );
    }
    final DateTime wakeUtc = lastCompleted.endUtc!.toUtc();
    final int sequence = _nextSequenceNumber(sorted, wakeUtc, location);
    final SleepType intendedType = _suggestType(wakeUtc, location, sequence);
    final List<AwakeWindowObservation> candidates = _selectComparable(
      observations: _statisticsService.buildAwakeWindows(
        events: sorted,
        nowUtc: nowUtc,
        location: location,
      ),
      nowUtc: nowUtc,
      sequence: sequence,
      intendedType: intendedType,
    );

    final tz.TZDateTime localNow = tz.TZDateTime.from(nowUtc, location);
    final int ageDays = AppDateTimeUtils.ageInDays(profile.birthDate, localNow);
    final WakeWindowReference ageReference = wakeReferenceForAgeDays(ageDays);

    if (candidates.length < 3) {
      final double centerMinutes =
          (ageReference.minimumMinutes + ageReference.maximumMinutes) / 2;
      final DateTime start =
          wakeUtc.add(Duration(minutes: ageReference.minimumMinutes));
      final DateTime center = wakeUtc.add(Duration(minutes: centerMinutes.round()));
      final DateTime end =
          wakeUtc.add(Duration(minutes: ageReference.maximumMinutes));
      return SleepPrediction(
        id: id,
        babyId: profile.id,
        generatedAtUtc: nowUtc.toUtc(),
        lastWakeUtc: wakeUtc,
        windowStartUtc: start,
        centerUtc: center,
        windowEndUtc: end,
        confidence: PredictionConfidence.low,
        observationCount: candidates.length,
        medianMinutes: centerMinutes,
        p25Minutes: ageReference.minimumMinutes.toDouble(),
        p75Minutes: ageReference.maximumMinutes.toDouble(),
        source: PredictionSource.age,
        explanation: candidates.isEmpty
            ? 'Todavía no hay ventanas personales suficientes. La estimación '
                'usa la referencia orientativa amplia para ${ageReference.label}. '
                'Observa también sus señales de sueño.'
            : 'Solo hay ${candidates.length} ventanas personales válidas. La '
                'estimación se basa principalmente en la edad y se irá ajustando '
                'con nuevos registros.',
        algorithmVersion: algorithmVersion,
        dataSnapshotJson: jsonEncode(<String, Object?>{
          'ageDays': ageDays,
          'referenceLabel': ageReference.label,
          'minimumMinutes': ageReference.minimumMinutes,
          'maximumMinutes': ageReference.maximumMinutes,
          'candidateCount': candidates.length,
          'candidateMinutes': candidates
              .map((AwakeWindowObservation item) => item.minutes)
              .toList(),
          'candidateObservations': _observationSnapshot(candidates),
          'lastWakeUtc': wakeUtc.toIso8601String(),
          'sleepSequenceNumber': sequence,
          'intendedType': intendedType.dbValue,
        }),
        sleepSequenceNumber: sequence,
        intendedType: intendedType,
      );
    }

    final List<double> values = candidates
        .map((AwakeWindowObservation item) => item.minutes)
        .toList(growable: false);
    final double median = StatMath.median(values)!;
    double p25 = StatMath.percentile(values, 0.25)!;
    double p75 = StatMath.percentile(values, 0.75)!;
    if (p75 - p25 < minimumIntervalWidth.inMinutes) {
      final double half = minimumIntervalWidth.inMinutes / 2;
      p25 = math.max(0, median - half);
      p75 = median + half;
    }
    final double iqr = p75 - p25;
    final double approximateRatio = candidates
            .where(
              (AwakeWindowObservation item) =>
                  item.nextSleepAccuracy == SleepAccuracy.approximate,
            )
            .length /
        candidates.length;
    final bool stale = _isStale(candidates, nowUtc);
    final List<AwakeWindowObservation> chronologicalCandidates =
        List<AwakeWindowObservation>.of(candidates)
          ..sort(
            (AwakeWindowObservation a, AwakeWindowObservation b) =>
                b.endUtc.compareTo(a.endUtc),
          );
    final bool recentChange = _hasRecentChange(
      chronologicalCandidates
          .map((AwakeWindowObservation item) => item.minutes)
          .toList(growable: false),
    );
    final PredictionConfidence confidence = confidenceFor(
      observationCount: candidates.length,
      iqrMinutes: iqr,
      approximateRatio: approximateRatio,
      stale: stale,
      recentPatternChange: recentChange,
    );

    final DateTime start = wakeUtc.add(Duration(minutes: p25.round()));
    final DateTime center = wakeUtc.add(Duration(minutes: median.round()));
    final DateTime end = wakeUtc.add(Duration(minutes: p75.round()));
    final String explanation = _explanation(
      count: candidates.length,
      median: median,
      p25: p25,
      p75: p75,
      confidence: confidence,
      stale: stale,
      recentChange: recentChange,
      approximateRatio: approximateRatio,
    );

    return SleepPrediction(
      id: id,
      babyId: profile.id,
      generatedAtUtc: nowUtc.toUtc(),
      lastWakeUtc: wakeUtc,
      windowStartUtc: start,
      centerUtc: center,
      windowEndUtc: end,
      confidence: confidence,
      observationCount: candidates.length,
      medianMinutes: median,
      p25Minutes: p25,
      p75Minutes: p75,
      source: PredictionSource.history,
      explanation: explanation,
      algorithmVersion: algorithmVersion,
      dataSnapshotJson: jsonEncode(<String, Object?>{
        'historyDays': historyWindow.inDays,
        'ageDays': ageDays,
        'ageReferenceLabel': ageReference.label,
        'lastWakeUtc': wakeUtc.toIso8601String(),
        'sleepSequenceNumber': sequence,
        'intendedType': intendedType.dbValue,
        'candidateMinutes': values,
        'candidateObservations': _observationSnapshot(candidates),
        'approximateRatio': approximateRatio,
        'iqrMinutes': iqr,
        'stale': stale,
        'recentPatternChange': recentChange,
      }),
      sleepSequenceNumber: sequence,
      intendedType: intendedType,
    );
  }

  BedtimeEstimate? estimateBedtime({
    required BabyProfile profile,
    required Iterable<SleepEvent> events,
    required DateTime nowUtc,
    required tz.Location location,
  }) {
    final DateTime cutoff = nowUtc.toUtc().subtract(historyWindow);
    final List<SleepEvent> nightEvents = events
        .where(
          (SleepEvent event) =>
              event.type == SleepType.night &&
              !event.startUtc.isBefore(cutoff) &&
              !event.startUtc.isAfter(nowUtc),
        )
        .toList(growable: false);
    final SleepEvent? lastCompleted = events
        .where((SleepEvent event) => event.endUtc != null)
        .fold<SleepEvent?>(null, (SleepEvent? latest, SleepEvent event) {
      return latest == null || event.endUtc!.isAfter(latest.endUtc!)
          ? event
          : latest;
    });
    if (lastCompleted == null ||
        lastCompleted.type != SleepType.nap ||
        lastCompleted.endUtc == null) {
      return null;
    }
    final SleepEvent lastNap = lastCompleted;

    final List<double> lastWakeWindows = <double>[];
    final List<SleepEvent> sorted = events.toList()
      ..sort((SleepEvent a, SleepEvent b) => a.startUtc.compareTo(b.startUtc));
    for (int i = 0; i < sorted.length; i += 1) {
      final SleepEvent event = sorted[i];
      if (event.type != SleepType.night || event.startUtc.isBefore(cutoff)) {
        continue;
      }
      SleepEvent? previous;
      for (int j = i - 1; j >= 0; j -= 1) {
        if (sorted[j].endUtc != null &&
            sorted[j].endUtc!.isBefore(event.startUtc)) {
          previous = sorted[j];
          break;
        }
      }
      if (previous?.endUtc != null) {
        lastWakeWindows.add(
          event.startUtc.difference(previous!.endUtc!).inSeconds / 60,
        );
      }
    }

    double centerMinutes;
    double lowMinutes;
    double highMinutes;
    PredictionSource source;
    String explanation;
    if (lastWakeWindows.length >= 3) {
      centerMinutes = StatMath.median(lastWakeWindows)!;
      lowMinutes = StatMath.percentile(lastWakeWindows, 0.25)!;
      highMinutes = StatMath.percentile(lastWakeWindows, 0.75)!;
      if (highMinutes - lowMinutes < 20) {
        lowMinutes = math.max(0, centerMinutes - 10);
        highMinutes = centerMinutes + 10;
      }
      source = PredictionSource.history;
      explanation = 'Estimación basada en ${lastWakeWindows.length} últimas '
          'ventanas antes del sueño nocturno.';
    } else {
      final tz.TZDateTime localNow = tz.TZDateTime.from(nowUtc, location);
      final int ageDays = AppDateTimeUtils.ageInDays(profile.birthDate, localNow);
      final WakeWindowReference reference = wakeReferenceForAgeDays(ageDays);
      lowMinutes = reference.minimumMinutes.toDouble();
      highMinutes = reference.maximumMinutes.toDouble();
      centerMinutes = (lowMinutes + highMinutes) / 2;
      source = PredictionSource.age;
      explanation = nightEvents.isEmpty
          ? 'Sin historial nocturno suficiente; se usa una referencia amplia por edad.'
          : 'Hay historial nocturno, pero aún no alcanza para calcular una mediana estable.';
    }
    return BedtimeEstimate(
      windowStartUtc:
          lastNap.endUtc!.add(Duration(minutes: lowMinutes.round())),
      centerUtc:
          lastNap.endUtc!.add(Duration(minutes: centerMinutes.round())),
      windowEndUtc:
          lastNap.endUtc!.add(Duration(minutes: highMinutes.round())),
      source: source,
      explanation: explanation,
    );
  }

  /// Reglas transparentes de confianza del algoritmo:
  /// - baja: menos de 5 observaciones, más de 40 % aproximadas, IQR mayor
  ///   a 60 minutos, datos antiguos o cambio reciente;
  /// - media: al menos 5 observaciones, IQR de hasta 60 minutos, mayoría
  ///   exacta y patrón reciente estable;
  /// - alta: al menos 10 observaciones recientes, IQR de hasta 30 minutos,
  ///   menos de 20 % aproximadas y sin cambio reciente importante.
  PredictionConfidence confidenceFor({
    required int observationCount,
    required double iqrMinutes,
    required double approximateRatio,
    required bool stale,
    required bool recentPatternChange,
  }) {
    if (observationCount >= 10 &&
        iqrMinutes <= 30 &&
        approximateRatio < 0.20 &&
        !stale &&
        !recentPatternChange) {
      return PredictionConfidence.high;
    }
    if (observationCount >= 5 &&
        iqrMinutes <= 60 &&
        approximateRatio <= 0.40 &&
        !stale &&
        !recentPatternChange) {
      return PredictionConfidence.medium;
    }
    return PredictionConfidence.low;
  }

  List<AwakeWindowObservation> _selectComparable({
    required List<AwakeWindowObservation> observations,
    required DateTime nowUtc,
    required int sequence,
    required SleepType intendedType,
  }) {
    final DateTime cutoff = nowUtc.toUtc().subtract(historyWindow);
    final List<AwakeWindowObservation> recent = observations
        .where(
          (AwakeWindowObservation item) =>
              !item.endUtc.isBefore(cutoff) && !item.endUtc.isAfter(nowUtc),
        )
        .toList();
    List<AwakeWindowObservation> selected = recent
        .where(
          (AwakeWindowObservation item) =>
              item.sleepSequenceNumber == sequence &&
              item.nextSleepType == intendedType,
        )
        .toList();
    if (selected.length < 3) {
      selected = recent
          .where(
            (AwakeWindowObservation item) =>
                item.nextSleepType == intendedType,
          )
          .toList();
    }
    if (selected.length < 3) {
      selected = recent;
    }
    selected.sort((AwakeWindowObservation a, AwakeWindowObservation b) {
      final int accuracyComparison =
          a.nextSleepAccuracy.index.compareTo(b.nextSleepAccuracy.index);
      if (accuracyComparison != 0) {
        return accuracyComparison;
      }
      return b.endUtc.compareTo(a.endUtc);
    });
    return selected.take(30).toList(growable: false);
  }

  SleepEvent? _lastCompleted(List<SleepEvent> events) {
    SleepEvent? result;
    for (final SleepEvent event in events) {
      if (event.endUtc != null &&
          (result == null || event.endUtc!.isAfter(result.endUtc!))) {
        result = event;
      }
    }
    return result;
  }

  int _nextSequenceNumber(
    List<SleepEvent> events,
    DateTime wakeUtc,
    tz.Location location,
  ) {
    final tz.TZDateTime wakeLocal = tz.TZDateTime.from(wakeUtc, location);
    return events.where((SleepEvent event) {
          final tz.TZDateTime local =
              tz.TZDateTime.from(event.startUtc, location);
          return local.year == wakeLocal.year &&
              local.month == wakeLocal.month &&
              local.day == wakeLocal.day &&
              !event.startUtc.isAfter(wakeUtc);
        }).length +
        1;
  }

  SleepType _suggestType(
    DateTime wakeUtc,
    tz.Location location,
    int sequence,
  ) {
    final tz.TZDateTime local = tz.TZDateTime.from(wakeUtc, location);
    return local.hour >= 17 || sequence >= 5 ? SleepType.night : SleepType.nap;
  }

  bool _isStale(
    List<AwakeWindowObservation> observations,
    DateTime nowUtc,
  ) {
    final DateTime latest = observations
        .map((AwakeWindowObservation item) => item.endUtc)
        .reduce((DateTime a, DateTime b) => a.isAfter(b) ? a : b);
    return nowUtc.toUtc().difference(latest).inDays >= 7;
  }

  bool _hasRecentChange(List<double> values) {
    if (values.length < 6) {
      return false;
    }
    final int section = math.max(2, values.length ~/ 3);
    final double newestMedian = StatMath.median(values.take(section))!;
    final double oldestMedian = StatMath.median(values.reversed.take(section))!;
    final double threshold = math.max(30, oldestMedian.abs() * 0.35);
    return (newestMedian - oldestMedian).abs() > threshold;
  }

  String _explanation({
    required int count,
    required double median,
    required double p25,
    required double p75,
    required PredictionConfidence confidence,
    required bool stale,
    required bool recentChange,
    required double approximateRatio,
  }) {
    final List<String> reasons = <String>[];
    if (stale) {
      reasons.add('los registros comparables son antiguos');
    }
    if (recentChange) {
      reasons.add('se observa un cambio reciente del patrón');
    }
    if (approximateRatio > 0.40) {
      reasons.add('varios horarios son aproximados');
    }
    if (p75 - p25 > 60) {
      reasons.add('existe alta variación entre días');
    }
    final String suffix = reasons.isEmpty
        ? 'El patrón reciente tiene una variación compatible con esta confianza.'
        : 'La confianza es ${confidence.label.toLowerCase()} porque ${reasons.join(' y ')}.';
    return 'Se utilizaron $count ventanas recientes. La mediana fue de '
        '${_minutesText(median)} y la mayoría estuvo entre '
        '${_minutesText(p25)} y ${_minutesText(p75)}. $suffix';
  }

  List<Map<String, Object?>> _observationSnapshot(
    Iterable<AwakeWindowObservation> observations,
  ) {
    return observations
        .map(
          (AwakeWindowObservation item) => <String, Object?>{
            'startUtc': item.startUtc.toIso8601String(),
            'endUtc': item.endUtc.toIso8601String(),
            'minutes': item.minutes,
            'nextSleepType': item.nextSleepType.dbValue,
            'nextSleepAccuracy': item.nextSleepAccuracy.dbValue,
            'sleepSequenceNumber': item.sleepSequenceNumber,
          },
        )
        .toList(growable: false);
  }

  String _minutesText(double value) {
    final int minutes = value.round();
    final int hours = minutes ~/ 60;
    final int remainder = minutes % 60;
    if (hours == 0) {
      return '$remainder min';
    }
    return remainder == 0 ? '$hours h' : '$hours h $remainder min';
  }
}
