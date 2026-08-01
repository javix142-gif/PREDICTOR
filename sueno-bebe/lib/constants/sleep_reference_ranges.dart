/// Referencias orientativas y no clínicas usadas solo como punto de partida.
/// Se mantienen centralizadas para poder revisarlas sin alterar el motor.
class WakeWindowReference {
  const WakeWindowReference({
    required this.minimumAgeDays,
    required this.maximumAgeDays,
    required this.minimumMinutes,
    required this.maximumMinutes,
    required this.label,
  });

  final int minimumAgeDays;
  final int maximumAgeDays;
  final int minimumMinutes;
  final int maximumMinutes;
  final String label;

  bool containsAge(int ageDays) =>
      ageDays >= minimumAgeDays && ageDays <= maximumAgeDays;
}

const List<WakeWindowReference> wakeWindowReferences = <WakeWindowReference>[
  WakeWindowReference(
    minimumAgeDays: 0,
    maximumAgeDays: 27,
    minimumMinutes: 35,
    maximumMinutes: 60,
    label: '0 a 4 semanas',
  ),
  WakeWindowReference(
    minimumAgeDays: 28,
    maximumAgeDays: 83,
    minimumMinutes: 60,
    maximumMinutes: 90,
    label: '4 a 12 semanas',
  ),
  WakeWindowReference(
    minimumAgeDays: 84,
    maximumAgeDays: 152,
    minimumMinutes: 75,
    maximumMinutes: 120,
    label: '3 a 4 meses',
  ),
  WakeWindowReference(
    minimumAgeDays: 153,
    maximumAgeDays: 212,
    minimumMinutes: 120,
    maximumMinutes: 180,
    label: '5 a 7 meses',
  ),
  WakeWindowReference(
    minimumAgeDays: 213,
    maximumAgeDays: 334,
    minimumMinutes: 150,
    maximumMinutes: 210,
    label: '7 a 10 meses',
  ),
  WakeWindowReference(
    minimumAgeDays: 335,
    maximumAgeDays: 456,
    minimumMinutes: 180,
    maximumMinutes: 240,
    label: '11 a 14 meses',
  ),
  WakeWindowReference(
    minimumAgeDays: 457,
    maximumAgeDays: 730,
    minimumMinutes: 240,
    maximumMinutes: 360,
    label: '14 a 24 meses',
  ),
];

WakeWindowReference wakeReferenceForAgeDays(int ageDays) {
  return wakeWindowReferences.firstWhere(
    (WakeWindowReference reference) => reference.containsAge(ageDays),
    orElse: () =>
        ageDays < 0 ? wakeWindowReferences.first : wakeWindowReferences.last,
  );
}

class SleepAmountReference {
  const SleepAmountReference({
    required this.minimumAgeMonths,
    required this.maximumAgeMonths,
    required this.minimumHours,
    required this.maximumHours,
    required this.label,
  });

  final int minimumAgeMonths;
  final int maximumAgeMonths;
  final int minimumHours;
  final int maximumHours;
  final String label;

  bool containsAge(int ageMonths) =>
      ageMonths >= minimumAgeMonths && ageMonths <= maximumAgeMonths;
}

const List<SleepAmountReference> sleepAmountReferences = <SleepAmountReference>[
  SleepAmountReference(
    minimumAgeMonths: 0,
    maximumAgeMonths: 3,
    minimumHours: 14,
    maximumHours: 17,
    label: '0 a 3 meses',
  ),
  SleepAmountReference(
    minimumAgeMonths: 4,
    maximumAgeMonths: 11,
    minimumHours: 12,
    maximumHours: 16,
    label: '4 a 11 meses',
  ),
  SleepAmountReference(
    minimumAgeMonths: 12,
    maximumAgeMonths: 24,
    minimumHours: 11,
    maximumHours: 14,
    label: '12 a 24 meses',
  ),
];

SleepAmountReference sleepAmountReferenceForAgeMonths(int ageMonths) {
  return sleepAmountReferences.firstWhere(
    (SleepAmountReference reference) => reference.containsAge(ageMonths),
    orElse: () => ageMonths < 0
        ? sleepAmountReferences.first
        : sleepAmountReferences.last,
  );
}
