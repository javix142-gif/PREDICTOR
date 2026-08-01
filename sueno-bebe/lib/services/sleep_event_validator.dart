import '../models/sleep_event.dart';

class SleepEventValidationException implements Exception {
  const SleepEventValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SleepEventValidator {
  const SleepEventValidator._();

  static const Duration futureClockTolerance = Duration(minutes: 5);

  static void validateBasic(
    SleepEvent event, {
    required DateTime nowUtc,
  }) {
    final DateTime now = nowUtc.toUtc();
    final DateTime latestAllowed = now.add(futureClockTolerance);
    if (event.startUtc.toUtc().isAfter(latestAllowed)) {
      throw const SleepEventValidationException(
        'La hora de inicio no puede estar en el futuro.',
      );
    }
    final DateTime? end = event.endUtc?.toUtc();
    if (end != null && !end.isAfter(event.startUtc.toUtc())) {
      throw const SleepEventValidationException(
        'La hora de término debe ser posterior al inicio.',
      );
    }
    if (end != null && end.isAfter(latestAllowed)) {
      throw const SleepEventValidationException(
        'La hora de término no puede estar en el futuro.',
      );
    }
  }

  static bool overlapsAny(
    SleepEvent candidate,
    Iterable<SleepEvent> existing, {
    required DateTime nowUtc,
  }) {
    return existing.any(
      (SleepEvent event) => overlaps(candidate, event, nowUtc: nowUtc),
    );
  }

  static bool overlaps(
    SleepEvent first,
    SleepEvent second, {
    required DateTime nowUtc,
  }) {
    final DateTime farFuture = DateTime.utc(9999, 12, 31);
    final DateTime firstEnd = first.endUtc?.toUtc() ?? farFuture;
    final DateTime secondEnd = second.endUtc?.toUtc() ?? farFuture;
    return first.startUtc.toUtc().isBefore(secondEnd) &&
        second.startUtc.toUtc().isBefore(firstEnd);
  }
}
