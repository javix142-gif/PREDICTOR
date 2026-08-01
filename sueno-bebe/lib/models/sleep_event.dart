enum SleepType {
  nap('siesta', 'Siesta'),
  night('nocturno', 'Sueño nocturno');

  const SleepType(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static SleepType fromDb(String value) =>
      values.firstWhere((SleepType item) => item.dbValue == value);
}

enum SleepAccuracy {
  exact('exacta', 'Exacta'),
  approximate('aproximada', 'Aproximada');

  const SleepAccuracy(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static SleepAccuracy fromDb(String value) =>
      values.firstWhere((SleepAccuracy item) => item.dbValue == value);
}

enum SleepOrigin {
  timer('cronometro', 'Cronómetro'),
  manual('manual', 'Ingreso manual');

  const SleepOrigin(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static SleepOrigin fromDb(String value) =>
      values.firstWhere((SleepOrigin item) => item.dbValue == value);
}

class SleepEvent {
  const SleepEvent({
    required this.id,
    required this.babyId,
    required this.startUtc,
    required this.type,
    required this.accuracy,
    required this.origin,
    required this.timezone,
    required this.createdAtUtc,
    required this.modifiedAtUtc,
    this.endUtc,
    this.notes,
  });

  final String id;
  final String babyId;
  final DateTime startUtc;
  final DateTime? endUtc;
  final SleepType type;
  final SleepAccuracy accuracy;
  final SleepOrigin origin;
  final String? notes;
  final String timezone;
  final DateTime createdAtUtc;
  final DateTime modifiedAtUtc;

  bool get isOpen => endUtc == null;

  Duration durationAt(DateTime nowUtc) {
    final DateTime end = endUtc ?? nowUtc.toUtc();
    return end.difference(startUtc.toUtc());
  }

  SleepEvent copyWith({
    String? id,
    String? babyId,
    DateTime? startUtc,
    DateTime? endUtc,
    bool clearEnd = false,
    SleepType? type,
    SleepAccuracy? accuracy,
    SleepOrigin? origin,
    String? notes,
    bool clearNotes = false,
    String? timezone,
    DateTime? createdAtUtc,
    DateTime? modifiedAtUtc,
  }) {
    return SleepEvent(
      id: id ?? this.id,
      babyId: babyId ?? this.babyId,
      startUtc: (startUtc ?? this.startUtc).toUtc(),
      endUtc: clearEnd ? null : (endUtc ?? this.endUtc)?.toUtc(),
      type: type ?? this.type,
      accuracy: accuracy ?? this.accuracy,
      origin: origin ?? this.origin,
      notes: clearNotes ? null : notes ?? this.notes,
      timezone: timezone ?? this.timezone,
      createdAtUtc: (createdAtUtc ?? this.createdAtUtc).toUtc(),
      modifiedAtUtc: (modifiedAtUtc ?? this.modifiedAtUtc).toUtc(),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'baby_id': babyId,
      'start_utc': startUtc.toUtc().millisecondsSinceEpoch,
      'end_utc': endUtc?.toUtc().millisecondsSinceEpoch,
      'type': type.dbValue,
      'status': isOpen ? 'abierto' : 'finalizado',
      'accuracy': accuracy.dbValue,
      'origin': origin.dbValue,
      'notes': notes,
      'timezone': timezone,
      'created_at_utc': createdAtUtc.toUtc().millisecondsSinceEpoch,
      'modified_at_utc': modifiedAtUtc.toUtc().millisecondsSinceEpoch,
    };
  }

  factory SleepEvent.fromMap(Map<String, Object?> map) {
    return SleepEvent(
      id: map['id']! as String,
      babyId: map['baby_id']! as String,
      startUtc: DateTime.fromMillisecondsSinceEpoch(
        map['start_utc']! as int,
        isUtc: true,
      ),
      endUtc: map['end_utc'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              map['end_utc']! as int,
              isUtc: true,
            ),
      type: SleepType.fromDb(map['type']! as String),
      accuracy: SleepAccuracy.fromDb(map['accuracy']! as String),
      origin: SleepOrigin.fromDb(map['origin']! as String),
      notes: map['notes'] as String?,
      timezone: map['timezone']! as String,
      createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['created_at_utc']! as int,
        isUtc: true,
      ),
      modifiedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['modified_at_utc']! as int,
        isUtc: true,
      ),
    );
  }
}
