class StatMath {
  const StatMath._();

  static double? average(Iterable<num> values) {
    final List<double> list =
        values.map((num value) => value.toDouble()).toList();
    if (list.isEmpty) {
      return null;
    }
    return list.reduce((double a, double b) => a + b) / list.length;
  }

  static double? median(Iterable<num> values) => percentile(values, 0.5);

  static double? percentile(Iterable<num> values, double proportion) {
    if (proportion < 0 || proportion > 1) {
      throw ArgumentError.value(
        proportion,
        'proportion',
        'Debe estar entre 0 y 1.',
      );
    }
    final List<double> sorted =
        values.map((num value) => value.toDouble()).toList()..sort();
    if (sorted.isEmpty) {
      return null;
    }
    if (sorted.length == 1) {
      return sorted.first;
    }
    final double index = (sorted.length - 1) * proportion;
    final int lower = index.floor();
    final int upper = index.ceil();
    if (lower == upper) {
      return sorted[lower];
    }
    final double fraction = index - lower;
    return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction;
  }

  static double? interquartileRange(Iterable<num> values) {
    final double? p25 = percentile(values, 0.25);
    final double? p75 = percentile(values, 0.75);
    return p25 == null || p75 == null ? null : p75 - p25;
  }

  static double? standardDeviation(Iterable<num> values) {
    final List<double> list =
        values.map((num value) => value.toDouble()).toList();
    final double? mean = average(list);
    if (mean == null || list.length < 2) {
      return null;
    }
    final double variance = list
            .map((double value) => (value - mean) * (value - mean))
            .reduce((double a, double b) => a + b) /
        list.length;
    return _sqrt(variance);
  }

  static double _sqrt(double value) {
    if (value <= 0) {
      return 0;
    }
    double estimate = value;
    for (int i = 0; i < 20; i += 1) {
      estimate = (estimate + value / estimate) / 2;
    }
    return estimate;
  }
}
