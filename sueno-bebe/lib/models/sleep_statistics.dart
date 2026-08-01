class DailySleepTotal {
  const DailySleepTotal({
    required this.localDate,
    required this.totalMinutes,
    required this.dayMinutes,
    required this.nightMinutes,
    required this.hasData,
  });

  final DateTime localDate;
  final double totalMinutes;
  final double dayMinutes;
  final double nightMinutes;
  final bool hasData;
}

class SleepStatistics {
  const SleepStatistics({
    required this.periodStartUtc,
    required this.periodEndUtc,
    required this.totalMinutes,
    required this.dayMinutes,
    required this.nightMinutes,
    required this.napCount,
    required this.nightCount,
    required this.daysWithDataCount,
    required this.dailyTotals,
    required this.napDurationsMinutes,
    required this.awakeWindowsMinutes,
    required this.evaluablePredictionCount,
    this.averageNapMinutes,
    this.medianNapMinutes,
    this.shortestNapMinutes,
    this.longestNapMinutes,
    this.longestContinuousSleepMinutes,
    this.medianNightStartMinuteOfDay,
    this.medianWakeMinuteOfDay,
    this.medianAwakeWindowMinutes,
    this.minimumAwakeWindowMinutes,
    this.maximumAwakeWindowMinutes,
    this.awakeWindowIqrMinutes,
    this.dailyVariabilityMinutes,
    this.medianPredictionErrorMinutes,
  });

  final DateTime periodStartUtc;
  final DateTime periodEndUtc;
  final double totalMinutes;
  final double dayMinutes;
  final double nightMinutes;
  final int napCount;
  final int nightCount;
  final int daysWithDataCount;
  final double? averageNapMinutes;
  final double? medianNapMinutes;
  final double? shortestNapMinutes;
  final double? longestNapMinutes;
  final double? longestContinuousSleepMinutes;
  final double? medianNightStartMinuteOfDay;
  final double? medianWakeMinuteOfDay;
  final double? medianAwakeWindowMinutes;
  final double? minimumAwakeWindowMinutes;
  final double? maximumAwakeWindowMinutes;
  final double? awakeWindowIqrMinutes;
  final double? dailyVariabilityMinutes;
  final int evaluablePredictionCount;
  final double? medianPredictionErrorMinutes;
  final List<DailySleepTotal> dailyTotals;
  final List<double> napDurationsMinutes;
  final List<double> awakeWindowsMinutes;

  bool get hasSleepData => totalMinutes > 0;
}
