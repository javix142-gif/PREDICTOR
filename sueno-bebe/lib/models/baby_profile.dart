class BabyProfile {
  const BabyProfile({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.timezone,
    required this.createdAtUtc,
    required this.modifiedAtUtc,
    this.expectedDueDate,
    this.notes,
  });

  final String id;
  final String name;
  final DateTime birthDate;
  final DateTime? expectedDueDate;
  final String? notes;
  final String timezone;
  final DateTime createdAtUtc;
  final DateTime modifiedAtUtc;

  BabyProfile copyWith({
    String? id,
    String? name,
    DateTime? birthDate,
    DateTime? expectedDueDate,
    bool clearExpectedDueDate = false,
    String? notes,
    bool clearNotes = false,
    String? timezone,
    DateTime? createdAtUtc,
    DateTime? modifiedAtUtc,
  }) {
    return BabyProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      expectedDueDate:
          clearExpectedDueDate ? null : expectedDueDate ?? this.expectedDueDate,
      notes: clearNotes ? null : notes ?? this.notes,
      timezone: timezone ?? this.timezone,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      modifiedAtUtc: modifiedAtUtc ?? this.modifiedAtUtc,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'birth_date': _dateOnly(birthDate),
      'expected_due_date':
          expectedDueDate == null ? null : _dateOnly(expectedDueDate!),
      'notes': notes,
      'timezone': timezone,
      'created_at_utc': createdAtUtc.toUtc().millisecondsSinceEpoch,
      'modified_at_utc': modifiedAtUtc.toUtc().millisecondsSinceEpoch,
    };
  }

  factory BabyProfile.fromMap(Map<String, Object?> map) {
    return BabyProfile(
      id: map['id']! as String,
      name: map['name']! as String,
      birthDate: DateTime.parse(map['birth_date']! as String),
      expectedDueDate: map['expected_due_date'] == null
          ? null
          : DateTime.parse(map['expected_due_date']! as String),
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

  static String _dateOnly(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
