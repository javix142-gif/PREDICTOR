enum TrackingCoverageLevel { incomplete, completeFewRecords, complete }

class TrackingCoverage {
  const TrackingCoverage({
    required this.level,
    required this.trackedDuration,
    required this.requestedPeriod,
    required this.completedEventCount,
    required this.trackingStartUtc,
  });

  final TrackingCoverageLevel level;
  final Duration trackedDuration;
  final Duration requestedPeriod;
  final int completedEventCount;
  final DateTime trackingStartUtc;

  bool get isComplete => level != TrackingCoverageLevel.incomplete;

  String get message => switch (level) {
    TrackingCoverageLevel.incomplete =>
      'Seguimiento incompleto. Aún faltan datos para comparar 24 horas completas.',
    TrackingCoverageLevel.completeFewRecords =>
      'Cobertura completa, pero todavía hay pocos registros.',
    TrackingCoverageLevel.complete => 'Cobertura suficiente para comparar.',
  };
}
