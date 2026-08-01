import 'package:flutter_test/flutter_test.dart';
import 'package:sueno_bebe/models/baby_profile.dart';
import 'package:sueno_bebe/models/sleep_event.dart';
import 'package:sueno_bebe/models/sleep_prediction.dart';
import 'package:sueno_bebe/services/prediction_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

BabyProfile profile(DateTime now) => BabyProfile(
      id: 'baby-1',
      name: 'Luna',
      birthDate: DateTime(2026, 4, 30),
      timezone: 'UTC',
      createdAtUtc: now.subtract(const Duration(days: 90)),
      modifiedAtUtc: now,
    );

SleepEvent completed({
  required String id,
  required DateTime start,
  required int sleepMinutes,
  SleepType type = SleepType.nap,
  SleepAccuracy accuracy = SleepAccuracy.exact,
}) {
  return SleepEvent(
    id: id,
    babyId: 'baby-1',
    startUtc: start,
    endUtc: start.add(Duration(minutes: sleepMinutes)),
    type: type,
    accuracy: accuracy,
    origin: SleepOrigin.manual,
    timezone: 'UTC',
    createdAtUtc: start,
    modifiedAtUtc: start,
  );
}

List<SleepEvent> historyWithWakeWindows(
  DateTime firstStart,
  List<int> wakeMinutes,
) {
  final List<SleepEvent> events = <SleepEvent>[];
  DateTime start = firstStart;
  for (int index = 0; index <= wakeMinutes.length; index += 1) {
    final SleepType type = index == wakeMinutes.length
        ? SleepType.nap
        : (index % 5 == 4 ? SleepType.night : SleepType.nap);
    final SleepEvent event = completed(
      id: 'event-$index',
      start: start,
      sleepMinutes: 30,
      type: type,
    );
    events.add(event);
    if (index < wakeMinutes.length) {
      start = event.endUtc!.add(Duration(minutes: wakeMinutes[index]));
    }
  }
  return events;
}

SleepPrediction basePrediction(DateTime now) => SleepPrediction(
      id: 'prediction-1',
      babyId: 'baby-1',
      generatedAtUtc: now,
      lastWakeUtc: now,
      windowStartUtc: now.add(const Duration(minutes: 80)),
      centerUtc: now.add(const Duration(minutes: 90)),
      windowEndUtc: now.add(const Duration(minutes: 100)),
      confidence: PredictionConfidence.medium,
      observationCount: 8,
      medianMinutes: 90,
      p25Minutes: 80,
      p75Minutes: 100,
      source: PredictionSource.history,
      explanation: 'Prueba',
      algorithmVersion: PredictionService.algorithmVersion,
      dataSnapshotJson: '{}',
      sleepSequenceNumber: 2,
      intendedType: SleepType.nap,
    );

void main() {
  late tz.Location utc;
  const PredictionService service = PredictionService();

  setUpAll(() {
    tz_data.initializeTimeZones();
    utc = tz.UTC;
  });

  test('11. predice con referencia por edad cuando no hay historial', () {
    final DateTime now = DateTime.utc(2026, 7, 31, 12);
    final SleepEvent last = completed(
      id: 'only',
      start: now.subtract(const Duration(hours: 1)),
      sleepMinutes: 30,
    );

    final SleepPrediction result = service.createPrediction(
      id: 'age-prediction',
      profile: profile(now),
      events: <SleepEvent>[last],
      nowUtc: now,
      location: utc,
    );

    expect(result.source, PredictionSource.age);
    expect(result.confidence, PredictionConfidence.low);
    expect(result.observationCount, 0);
    expect(result.windowEndUtc.isAfter(result.windowStartUtc), isTrue);
  });

  test('12. predice con mediana e intervalo usando historial', () {
    final DateTime now = DateTime.utc(2026, 7, 31, 18);
    final List<SleepEvent> events = historyWithWakeWindows(
      DateTime.utc(2026, 7, 30, 2),
      <int>[80, 90, 100, 110],
    );

    final SleepPrediction result = service.createPrediction(
      id: 'history-prediction',
      profile: profile(now),
      events: events,
      nowUtc: now,
      location: utc,
    );

    expect(result.source, PredictionSource.history);
    expect(result.observationCount, greaterThanOrEqualTo(3));
    expect(result.medianMinutes, isNotNull);
    expect(
      result.windowEndUtc.difference(result.windowStartUtc).inMinutes,
      greaterThanOrEqualTo(20),
    );
  });

  test('13. asigna confianza baja con pocas observaciones', () {
    expect(
      service.confidenceFor(
        observationCount: 4,
        iqrMinutes: 20,
        approximateRatio: 0,
        stale: false,
        recentPatternChange: false,
      ),
      PredictionConfidence.low,
    );
  });

  test('14. asigna confianza media con cinco observaciones consistentes', () {
    expect(
      service.confidenceFor(
        observationCount: 6,
        iqrMinutes: 40,
        approximateRatio: 0.2,
        stale: false,
        recentPatternChange: false,
      ),
      PredictionConfidence.medium,
    );
  });

  test('15. asigna confianza alta con historial reciente y estable', () {
    expect(
      service.confidenceFor(
        observationCount: 12,
        iqrMinutes: 24,
        approximateRatio: 0.1,
        stale: false,
        recentPatternChange: false,
      ),
      PredictionConfidence.high,
    );
  });

  test('16. evalúa una predicción sin modificar su intervalo original', () {
    final DateTime now = DateTime.utc(2026, 7, 31, 12);
    final SleepPrediction original = basePrediction(now);
    final DateTime actual = now.add(const Duration(minutes: 96));

    final SleepPrediction evaluated = original.evaluate(
      actualStartUtc: actual,
      evaluatedAtUtc: actual,
    );

    expect(evaluated.errorMinutes, 6);
    expect(evaluated.startedWithinWindow, isTrue);
    expect(evaluated.windowStartUtc, original.windowStartUtc);
    expect(evaluated.centerUtc, original.centerUtc);
    expect(evaluated.windowEndUtc, original.windowEndUtc);
    expect(evaluated.isEvaluated, isTrue);
  });

  test('marca confianza baja cuando predominan horarios aproximados', () {
    expect(
      service.confidenceFor(
        observationCount: 12,
        iqrMinutes: 20,
        approximateRatio: 0.5,
        stale: false,
        recentPatternChange: false,
      ),
      PredictionConfidence.low,
    );
  });
}
