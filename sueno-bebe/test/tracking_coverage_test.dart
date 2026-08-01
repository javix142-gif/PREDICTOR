import 'package:flutter_test/flutter_test.dart';
import 'package:sueno_bebe/controllers/app_controller.dart';
import 'package:sueno_bebe/models/baby_profile.dart';
import 'package:sueno_bebe/models/sleep_event.dart';
import 'package:sueno_bebe/models/tracking_coverage.dart';
import 'package:timezone/data/latest.dart' as tz_data;

SleepEvent event({
  required String id,
  required DateTime start,
  required DateTime end,
  SleepType type = SleepType.nap,
}) {
  return SleepEvent(
    id: id,
    babyId: 'baby-1',
    startUtc: start,
    endUtc: end,
    type: type,
    accuracy: SleepAccuracy.exact,
    origin: SleepOrigin.manual,
    timezone: 'UTC',
    createdAtUtc: start,
    modifiedAtUtc: end,
  );
}

BabyProfile profile(DateTime createdAt) => BabyProfile(
  id: 'baby-1',
  name: 'Luna',
  birthDate: DateTime(2026, 5, 1),
  timezone: 'UTC',
  createdAtUtc: createdAt,
  modifiedAtUtc: createdAt,
);

void main() {
  setUpAll(tz_data.initializeTimeZones);

  test('cobertura inferior a 24 horas no permite comparar', () {
    final DateTime now = DateTime.utc(2026, 8, 1, 12);
    final AppController controller = AppController(nowProvider: () => now)
      ..profile = profile(now.subtract(const Duration(hours: 12)))
      ..events = <SleepEvent>[
        event(
          id: 'recent',
          start: now.subtract(const Duration(hours: 2)),
          end: now.subtract(const Duration(hours: 1)),
        ),
      ];

    final TrackingCoverage coverage = controller.trackingCoverage(
      const Duration(hours: 24),
    );

    expect(coverage.level, TrackingCoverageLevel.incomplete);
    expect(
      controller.sleepRangeStatus(),
      'Seguimiento incompleto. Aún faltan datos para comparar 24 horas completas.',
    );
  });

  test('después de 24 horas y tres registros la cobertura es completa', () {
    final DateTime now = DateTime.utc(2026, 8, 2, 12);
    final AppController controller = AppController(nowProvider: () => now)
      ..profile = profile(now.subtract(const Duration(days: 2)))
      ..events = <SleepEvent>[
        event(
          id: 'one',
          start: now.subtract(const Duration(hours: 30)),
          end: now.subtract(const Duration(hours: 29)),
        ),
        event(
          id: 'two',
          start: now.subtract(const Duration(hours: 20)),
          end: now.subtract(const Duration(hours: 19)),
        ),
        event(
          id: 'three',
          start: now.subtract(const Duration(hours: 4)),
          end: now.subtract(const Duration(hours: 3)),
        ),
      ];

    expect(
      controller.trackingCoverage(const Duration(hours: 24)).level,
      TrackingCoverageLevel.complete,
    );
  });

  test('a las 02:00 el último tramo nocturno produce despertar nocturno', () {
    final DateTime now = DateTime.utc(2026, 8, 1, 2);
    final AppController controller = AppController(nowProvider: () => now)
      ..profile = profile(now.subtract(const Duration(days: 2)))
      ..events = <SleepEvent>[
        event(
          id: 'night',
          start: DateTime.utc(2026, 7, 31, 22),
          end: now,
          type: SleepType.night,
        ),
      ];

    expect(controller.isNightAwakening, isTrue);
    expect(controller.suggestedSleepType(), SleepType.night);
  });

  test('a las 07:00 el despertar nocturno deja de estar activo', () {
    final DateTime now = DateTime.utc(2026, 8, 1, 7);
    final AppController controller = AppController(nowProvider: () => now)
      ..profile = profile(now.subtract(const Duration(days: 2)))
      ..events = <SleepEvent>[
        event(
          id: 'night',
          start: DateTime.utc(2026, 7, 31, 22),
          end: now,
          type: SleepType.night,
        ),
      ];

    expect(controller.isNightAwakening, isFalse);
    expect(controller.suggestedSleepType(), SleepType.nap);
  });
}
