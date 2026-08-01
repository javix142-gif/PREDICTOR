import 'package:flutter_test/flutter_test.dart';
import 'package:sueno_bebe/models/sleep_event.dart';
import 'package:sueno_bebe/services/sleep_event_validator.dart';

SleepEvent event({
  required String id,
  required DateTime start,
  DateTime? end,
}) {
  final DateTime created = DateTime.utc(2026, 7, 1);
  return SleepEvent(
    id: id,
    babyId: 'baby-1',
    startUtc: start,
    endUtc: end,
    type: SleepType.nap,
    accuracy: SleepAccuracy.exact,
    origin: SleepOrigin.manual,
    timezone: 'UTC',
    createdAtUtc: created,
    modifiedAtUtc: created,
  );
}

void main() {
  final DateTime now = DateTime.utc(2026, 7, 31, 12);

  test('1. calcula la duración de un evento finalizado', () {
    final SleepEvent value = event(
      id: 'duration',
      start: DateTime.utc(2026, 7, 31, 8),
      end: DateTime.utc(2026, 7, 31, 9, 35),
    );

    expect(value.durationAt(now), const Duration(minutes: 95));
  });

  test('2. permite un evento que cruza medianoche', () {
    final SleepEvent value = event(
      id: 'midnight',
      start: DateTime.utc(2026, 7, 30, 22, 30),
      end: DateTime.utc(2026, 7, 31, 6, 15),
    );

    expect(
      () => SleepEventValidator.validateBasic(value, nowUtc: now),
      returnsNormally,
    );
    expect(value.durationAt(now), const Duration(hours: 7, minutes: 45));
  });

  test('4. detecta superposición entre eventos', () {
    final SleepEvent first = event(
      id: 'first',
      start: DateTime.utc(2026, 7, 31, 8),
      end: DateTime.utc(2026, 7, 31, 10),
    );
    final SleepEvent second = event(
      id: 'second',
      start: DateTime.utc(2026, 7, 31, 9, 30),
      end: DateTime.utc(2026, 7, 31, 11),
    );

    expect(
      SleepEventValidator.overlaps(first, second, nowUtc: now),
      isTrue,
    );
  });

  test('18. rechaza término anterior o igual al inicio', () {
    final DateTime start = DateTime.utc(2026, 7, 31, 10);
    final List<SleepEvent> invalidEvents = <SleepEvent>[
      event(
        id: 'invalid-before',
        start: start,
        end: start.subtract(const Duration(minutes: 1)),
      ),
      event(id: 'invalid-equal', start: start, end: start),
    ];

    for (final SleepEvent invalid in invalidEvents) {
      expect(
        () => SleepEventValidator.validateBasic(invalid, nowUtc: now),
        throwsA(isA<SleepEventValidationException>()),
      );
    }
  });

  test('rechaza un inicio futuro fuera de la tolerancia de reloj', () {
    final SleepEvent invalid = event(
      id: 'future',
      start: now.add(const Duration(minutes: 6)),
      end: now.add(const Duration(minutes: 10)),
    );

    expect(
      () => SleepEventValidator.validateBasic(invalid, nowUtc: now),
      throwsA(isA<SleepEventValidationException>()),
    );
  });

  test('los eventos contiguos no se consideran superpuestos', () {
    final SleepEvent first = event(
      id: 'contiguous-1',
      start: DateTime.utc(2026, 7, 31, 8),
      end: DateTime.utc(2026, 7, 31, 9),
    );
    final SleepEvent second = event(
      id: 'contiguous-2',
      start: DateTime.utc(2026, 7, 31, 9),
      end: DateTime.utc(2026, 7, 31, 10),
    );

    expect(
      SleepEventValidator.overlaps(first, second, nowUtc: now),
      isFalse,
    );
  });
}
