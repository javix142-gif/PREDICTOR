import 'sleep_event.dart';

enum PredictionConfidence {
  low('baja', 'Baja'),
  medium('media', 'Media'),
  high('alta', 'Alta');

  const PredictionConfidence(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static PredictionConfidence fromDb(String value) => values.firstWhere(
        (PredictionConfidence item) => item.dbValue == value,
      );
}

enum PredictionSource {
  age('edad', 'Referencia por edad'),
  history('historial', 'Historial reciente');

  const PredictionSource(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static PredictionSource fromDb(String value) =>
      values.firstWhere((PredictionSource item) => item.dbValue == value);
}

class SleepPrediction {
  const SleepPrediction({
    required this.id,
    required this.babyId,
    required this.generatedAtUtc,
    required this.lastWakeUtc,
    required this.windowStartUtc,
    required this.centerUtc,
    required this.windowEndUtc,
    required this.confidence,
    required this.observationCount,
    required this.source,
    required this.explanation,
    required this.algorithmVersion,
    required this.dataSnapshotJson,
    required this.sleepSequenceNumber,
    required this.intendedType,
    this.medianMinutes,
    this.p25Minutes,
    this.p75Minutes,
    this.evaluatedAtUtc,
    this.actualSleepStartUtc,
    this.errorMinutes,
    this.startedWithinWindow,
  });

  final String id;
  final String babyId;
  final DateTime generatedAtUtc;
  final DateTime lastWakeUtc;
  final DateTime windowStartUtc;
  final DateTime centerUtc;
  final DateTime windowEndUtc;
  final PredictionConfidence confidence;
  final int observationCount;
  final double? medianMinutes;
  final double? p25Minutes;
  final double? p75Minutes;
  final PredictionSource source;
  final String explanation;
  final String algorithmVersion;
  final String dataSnapshotJson;
  final int sleepSequenceNumber;
  final SleepType intendedType;
  final DateTime? evaluatedAtUtc;
  final DateTime? actualSleepStartUtc;
  final int? errorMinutes;
  final bool? startedWithinWindow;

  bool get isEvaluated => evaluatedAtUtc != null;

  SleepPrediction evaluate({
    required DateTime actualStartUtc,
    required DateTime evaluatedAtUtc,
  }) {
    final DateTime actual = actualStartUtc.toUtc();
    return copyWith(
      evaluatedAtUtc: evaluatedAtUtc.toUtc(),
      actualSleepStartUtc: actual,
      errorMinutes: actual.difference(centerUtc).inMinutes.abs(),
      startedWithinWindow:
          !actual.isBefore(windowStartUtc) && !actual.isAfter(windowEndUtc),
    );
  }

  SleepPrediction copyWith({
    DateTime? evaluatedAtUtc,
    DateTime? actualSleepStartUtc,
    int? errorMinutes,
    bool? startedWithinWindow,
  }) {
    return SleepPrediction(
      id: id,
      babyId: babyId,
      generatedAtUtc: generatedAtUtc,
      lastWakeUtc: lastWakeUtc,
      windowStartUtc: windowStartUtc,
      centerUtc: centerUtc,
      windowEndUtc: windowEndUtc,
      confidence: confidence,
      observationCount: observationCount,
      medianMinutes: medianMinutes,
      p25Minutes: p25Minutes,
      p75Minutes: p75Minutes,
      source: source,
      explanation: explanation,
      algorithmVersion: algorithmVersion,
      dataSnapshotJson: dataSnapshotJson,
      sleepSequenceNumber: sleepSequenceNumber,
      intendedType: intendedType,
      evaluatedAtUtc: evaluatedAtUtc ?? this.evaluatedAtUtc,
      actualSleepStartUtc: actualSleepStartUtc ?? this.actualSleepStartUtc,
      errorMinutes: errorMinutes ?? this.errorMinutes,
      startedWithinWindow:
          startedWithinWindow ?? this.startedWithinWindow,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'baby_id': babyId,
      'generated_at_utc': generatedAtUtc.millisecondsSinceEpoch,
      'last_wake_utc': lastWakeUtc.millisecondsSinceEpoch,
      'window_start_utc': windowStartUtc.millisecondsSinceEpoch,
      'center_utc': centerUtc.millisecondsSinceEpoch,
      'window_end_utc': windowEndUtc.millisecondsSinceEpoch,
      'confidence': confidence.dbValue,
      'observation_count': observationCount,
      'median_minutes': medianMinutes,
      'p25_minutes': p25Minutes,
      'p75_minutes': p75Minutes,
      'source': source.dbValue,
      'explanation': explanation,
      'algorithm_version': algorithmVersion,
      'data_snapshot_json': dataSnapshotJson,
      'sleep_sequence_number': sleepSequenceNumber,
      'intended_type': intendedType.dbValue,
      'evaluated_at_utc': evaluatedAtUtc?.millisecondsSinceEpoch,
      'actual_sleep_start_utc': actualSleepStartUtc?.millisecondsSinceEpoch,
      'error_minutes': errorMinutes,
      'started_within_window': startedWithinWindow == null
          ? null
          : startedWithinWindow!
              ? 1
              : 0,
    };
  }

  factory SleepPrediction.fromMap(Map<String, Object?> map) {
    DateTime? optionalDate(String key) {
      final Object? value = map[key];
      return value == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(value as int, isUtc: true);
    }

    return SleepPrediction(
      id: map['id']! as String,
      babyId: map['baby_id']! as String,
      generatedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['generated_at_utc']! as int,
        isUtc: true,
      ),
      lastWakeUtc: DateTime.fromMillisecondsSinceEpoch(
        map['last_wake_utc']! as int,
        isUtc: true,
      ),
      windowStartUtc: DateTime.fromMillisecondsSinceEpoch(
        map['window_start_utc']! as int,
        isUtc: true,
      ),
      centerUtc: DateTime.fromMillisecondsSinceEpoch(
        map['center_utc']! as int,
        isUtc: true,
      ),
      windowEndUtc: DateTime.fromMillisecondsSinceEpoch(
        map['window_end_utc']! as int,
        isUtc: true,
      ),
      confidence:
          PredictionConfidence.fromDb(map['confidence']! as String),
      observationCount: map['observation_count']! as int,
      medianMinutes: (map['median_minutes'] as num?)?.toDouble(),
      p25Minutes: (map['p25_minutes'] as num?)?.toDouble(),
      p75Minutes: (map['p75_minutes'] as num?)?.toDouble(),
      source: PredictionSource.fromDb(map['source']! as String),
      explanation: map['explanation']! as String,
      algorithmVersion: map['algorithm_version']! as String,
      dataSnapshotJson: map['data_snapshot_json']! as String,
      sleepSequenceNumber: map['sleep_sequence_number']! as int,
      intendedType: SleepType.fromDb(map['intended_type']! as String),
      evaluatedAtUtc: optionalDate('evaluated_at_utc'),
      actualSleepStartUtc: optionalDate('actual_sleep_start_utc'),
      errorMinutes: map['error_minutes'] as int?,
      startedWithinWindow: map['started_within_window'] == null
          ? null
          : map['started_within_window'] == 1,
    );
  }
}

class BedtimeEstimate {
  const BedtimeEstimate({
    required this.windowStartUtc,
    required this.centerUtc,
    required this.windowEndUtc,
    required this.source,
    required this.explanation,
  });

  final DateTime windowStartUtc;
  final DateTime centerUtc;
  final DateTime windowEndUtc;
  final PredictionSource source;
  final String explanation;
}
