import 'package:flutter_test/flutter_test.dart';
import 'package:sueno_bebe/models/sleep_event.dart';
import 'package:sueno_bebe/models/sleep_prediction.dart';
import 'package:sueno_bebe/services/statistics_service.dart';
import 'package:sueno_bebe/utils/stat_math.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

SleepEvent sleep({
  required String id,
  required DateTime start,
  required DateTime end,
  SleepType type = SleepType.nap,
  SleepAccuracy accuracy = SleepAccuracy.exact,
}) {
  return SleepEvent(
    id: id,
    babyId: 'baby-1',
    startUtc: start,
    endUtc: end,
    type: type,
    accuracy: accuracy,
    origin: SleepOrigin.manual,
    timezone: 'UTC',
    createdAtUtc: start,
    modifiedAtUtc: start,
  );
}

void main() {
  late tz.Location utc;
  const StatisticsService service = StatisticsService();

  setUpAll(() {
    tz_data.initializeTimeZones();
    utc = tz.UTC;
  });

  test('3. recorta correctamente eventos en las últimas 24 horas', () {
    final DateTime now = DateTime.utc(2026, 7, 31, 12);
    final SleepEvent value = sleep(
      id: 'clip',
      start: DateTime.utc(2026, 7, 30, 10),
      end: DateTime.utc(2026, 7, 30, 14),
    );

    expect(
      service.rollingSleepMinutes(events: <SleepEvent>[value], nowUtc: now),
      120,
    );
  });

  test('5. calcula promedio', () {
    expect(StatMath.average(<double>[30, 60, 90]), 60);
  });

  test('6. calcula mediana para cantidad par e impar', () {
    expect(StatMath.median(<double>[10, 50, 30]), 30);
    expect(StatMath.median(<double>[10, 20, 30, 40]), 25);
  });

  test('7. calcula percentiles con interpolación lineal', () {
    expect(StatMath.percentile(<double>[0, 10, 20, 30, 40], 0.25), 10);
    expect(StatMath.percentile(<double>[0, 10, 20, 30], 0.75), 22.5);
  });

  test('8. calcula rango intercuartílico', () {
    expect(
      StatMath.interquartileRange(<double>[0, 10, 20, 30, 40]),
      20,
    );
  });

  test('9. devuelve estadísticas vacías sin inventar datos', () {
    final DateTime now = DateTime.utc(2026, 7, 31, 12);
    final result = service.calculate(
      events: const <SleepEvent>[],
      predictions: const <SleepPrediction>[],
      period: const Duration(days: 7),
      nowUtc: now,
      location: utc,
    );

    expect(result.totalMinutes, 0);
    expect(result.napCount, 0);
    expect(result.averageNapMinutes, isNull);
    expect(result.medianAwakeWindowMinutes, isNull);
    expect(result.hasSleepData, isFalse);
  });

  test('10. calcula estadísticas de varios días y separa día/noche', () {
    final DateTime now = DateTime.utc(2026, 7, 31, 12);
    final List<SleepEvent> events = <SleepEvent>[
      sleep(
        id: 'night-1',
        start: DateTime.utc(2026, 7, 29, 22),
        end: DateTime.utc(2026, 7, 30, 6),
        type: SleepType.night,
      ),
      sleep(
        id: 'nap-1',
        start: DateTime.utc(2026, 7, 30, 10),
        end: DateTime.utc(2026, 7, 30, 11),
      ),
      sleep(
        id: 'nap-2',
        start: DateTime.utc(2026, 7, 30, 15),
        end: DateTime.utc(2026, 7, 30, 16, 30),
      ),
      sleep(
        id: 'night-2',
        start: DateTime.utc(2026, 7, 30, 22),
        end: DateTime.utc(2026, 7, 31, 6, 30),
        type: SleepType.night,
      ),
    ];

    final result = service.calculate(
      events: events,
      predictions: const <SleepPrediction>[],
      period: const Duration(days: 3),
      nowUtc: now,
      location: utc,
    );

    expect(result.totalMinutes, 1140);
    expect(result.dayMinutes, 150);
    expect(result.nightMinutes, 990);
    expect(result.napCount, 2);
    expect(result.averageNapMinutes, 75);
    expect(result.medianNapMinutes, 75);
    expect(result.longestContinuousSleepMinutes, 510);
    expect(result.dailyTotals.where((day) => day.totalMinutes > 0), hasLength(3));
  });

  test('17. una modificación recalcula los totales', () {
    final DateTime now = DateTime.utc(2026, 7, 31, 12);
    final SleepEvent original = sleep(
      id: 'edited',
      start: DateTime.utc(2026, 7, 31, 8),
      end: DateTime.utc(2026, 7, 31, 9),
    );
    final SleepEvent edited = original.copyWith(
      endUtc: DateTime.utc(2026, 7, 31, 10),
      modifiedAtUtc: now,
    );

    final before = service.calculate(
      events: <SleepEvent>[original],
      predictions: const <SleepPrediction>[],
      period: const Duration(hours: 24),
      nowUtc: now,
      location: utc,
    );
    final after = service.calculate(
      events: <SleepEvent>[edited],
      predictions: const <SleepPrediction>[],
      period: const Duration(hours: 24),
      nowUtc: now,
      location: utc,
    );

    expect(before.totalMinutes, 60);
    expect(after.totalMinutes, 120);
  });
}
