import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../models/sleep_statistics.dart';
import '../models/tracking_coverage.dart';
import '../services/statistics_service.dart';
import '../utils/date_time_utils.dart';
import '../widgets/empty_state.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppController controller = context.watch<AppController>();
    final SleepStatistics? statistics = controller.selectedStatistics;
    final TrackingCoverage coverage = controller.trackingCoverage(
      controller.statisticsPeriod,
    );
    return ListView(
      key: const Key('statistics-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<int>(
            segments: const <ButtonSegment<int>>[
              ButtonSegment<int>(value: 1, label: Text('24 h')),
              ButtonSegment<int>(value: 7, label: Text('7 d')),
              ButtonSegment<int>(value: 14, label: Text('14 d')),
              ButtonSegment<int>(value: 30, label: Text('30 d')),
            ],
            selected: <int>{_periodKey(controller.statisticsPeriod)},
            onSelectionChanged: (Set<int> value) {
              final int days = value.first;
              controller.setStatisticsPeriod(
                days == 1 ? const Duration(hours: 24) : Duration(days: days),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        _CoverageBanner(coverage: coverage),
        const SizedBox(height: 14),
        if (statistics == null || !statistics.hasSleepData)
          const EmptyState(
            key: Key('statistics-empty'),
            icon: Icons.query_stats_rounded,
            title: 'Aún no hay sueño registrado',
            message:
                'Los días sin registros se muestran como “sin datos”, no como cero horas.',
          )
        else
          StatisticsSections(statistics: statistics, coverage: coverage),
      ],
    );
  }

  int _periodKey(Duration duration) {
    if (duration.inHours == 24) {
      return 1;
    }
    return duration.inDays;
  }
}

class StatisticsSections extends StatelessWidget {
  const StatisticsSections({
    required this.statistics,
    required this.coverage,
    super.key,
  });

  final SleepStatistics statistics;
  final TrackingCoverage coverage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _PrimaryMetrics(statistics: statistics),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Resumen',
          icon: Icons.dashboard_outlined,
          initiallyExpanded: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('Sueño total por día'),
              const SizedBox(height: 10),
              SizedBox(
                height: 230,
                child: DailySleepChart(data: statistics.dailyTotals),
              ),
              const SizedBox(height: 18),
              _DistributionBar(
                dayMinutes: statistics.dayMinutes,
                nightMinutes: statistics.nightMinutes,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SectionCard(
          title: 'Siestas',
          icon: Icons.light_mode_outlined,
          child: _SectionMetrics(
            message: statistics.napCount < StatisticsMinimums.napPatternCount
                ? 'Se necesitan al menos 2 siestas para mostrar media y mediana como patrón.'
                : null,
            metrics: <_Metric>[
              _Metric('Cantidad', statistics.napCount.toString()),
              _Metric(
                'Media',
                AppDateTimeUtils.formatMinutes(statistics.averageNapMinutes),
              ),
              _Metric(
                'Mediana',
                AppDateTimeUtils.formatMinutes(statistics.medianNapMinutes),
              ),
              _Metric(
                'Más corta',
                AppDateTimeUtils.formatMinutes(statistics.shortestNapMinutes),
              ),
              _Metric(
                'Más larga',
                AppDateTimeUtils.formatMinutes(statistics.longestNapMinutes),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SectionCard(
          title: 'Sueño nocturno',
          icon: Icons.dark_mode_outlined,
          child: _SectionMetrics(
            message:
                statistics.nightCount < StatisticsMinimums.nightPatternCount
                ? 'Se necesitan al menos 3 noches para mostrar horarios medianos.'
                : null,
            metrics: <_Metric>[
              _Metric('Noches con datos', statistics.nightCount.toString()),
              _Metric(
                'Inicio mediano',
                _minuteOfDay(statistics.medianNightStartMinuteOfDay),
              ),
              _Metric(
                'Despertar mediano',
                _minuteOfDay(statistics.medianWakeMinuteOfDay),
              ),
              _Metric(
                'Tramo continuo más largo',
                AppDateTimeUtils.formatMinutes(
                  statistics.longestContinuousSleepMinutes,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SectionCard(
          title: 'Ventanas despierto',
          icon: Icons.timelapse_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _SectionMetrics(
                message:
                    statistics.awakeWindowsMinutes.length <
                        StatisticsMinimums.awakeMedianCount
                    ? 'Se necesitan al menos 3 ventanas para mostrar una mediana y 4 para el rango intercuartílico.'
                    : statistics.awakeWindowsMinutes.length <
                          StatisticsMinimums.awakeIqrCount
                    ? 'La mediana ya está disponible; falta una ventana para calcular el rango intercuartílico.'
                    : null,
                metrics: <_Metric>[
                  _Metric(
                    'Ventanas registradas',
                    statistics.awakeWindowsMinutes.length.toString(),
                  ),
                  _Metric(
                    'Mediana',
                    AppDateTimeUtils.formatMinutes(
                      statistics.medianAwakeWindowMinutes,
                    ),
                  ),
                  _Metric(
                    'Rango intercuartílico',
                    AppDateTimeUtils.formatMinutes(
                      statistics.awakeWindowIqrMinutes,
                    ),
                  ),
                  _Metric(
                    'Mínima',
                    AppDateTimeUtils.formatMinutes(
                      statistics.minimumAwakeWindowMinutes,
                    ),
                  ),
                  _Metric(
                    'Máxima',
                    AppDateTimeUtils.formatMinutes(
                      statistics.maximumAwakeWindowMinutes,
                    ),
                  ),
                ],
              ),
              if (statistics.awakeWindowsMinutes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                SizedBox(
                  height: 190,
                  child: _AwakeLineChart(
                    values: statistics.awakeWindowsMinutes,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SectionCard(
          title: 'Predicciones',
          icon: Icons.auto_graph_rounded,
          child: _SectionMetrics(
            message:
                statistics.evaluablePredictionCount <
                    StatisticsMinimums.predictionErrorCount
                ? 'Se necesitan al menos 5 predicciones evaluadas para mostrar un error mediano.'
                : null,
            metrics: <_Metric>[
              _Metric(
                'Evaluadas',
                statistics.evaluablePredictionCount.toString(),
              ),
              _Metric(
                'Error mediano',
                AppDateTimeUtils.formatMinutes(
                  statistics.medianPredictionErrorMinutes,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SectionCard(
          title: 'Calidad de datos',
          icon: Icons.fact_check_outlined,
          child: _SectionMetrics(
            message:
                statistics.daysWithDataCount <
                    StatisticsMinimums.dailyVariabilityCount
                ? 'Se necesitan al menos 3 días con registros para calcular variabilidad diaria.'
                : null,
            metrics: <_Metric>[
              _Metric(
                'Días con datos',
                statistics.daysWithDataCount.toString(),
              ),
              _Metric(
                'Eventos finalizados',
                coverage.completedEventCount.toString(),
              ),
              _Metric(
                'Variabilidad diaria',
                AppDateTimeUtils.formatMinutes(
                  statistics.dailyVariabilityMinutes,
                ),
              ),
              _Metric(
                'Cobertura',
                coverage.isComplete ? 'Completa' : 'Incompleta',
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _minuteOfDay(double? value) {
    if (value == null) {
      return 'Aún no disponible';
    }
    final int total = value.round() % (24 * 60);
    return '${(total ~/ 60).toString().padLeft(2, '0')}:'
        '${(total % 60).toString().padLeft(2, '0')}';
  }
}

class _CoverageBanner extends StatelessWidget {
  const _CoverageBanner({required this.coverage});

  final TrackingCoverage coverage;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              coverage.level == TrackingCoverageLevel.complete
                  ? Icons.check_circle_outline_rounded
                  : Icons.hourglass_bottom_rounded,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(coverage.message)),
          ],
        ),
      ),
    );
  }
}

class _PrimaryMetrics extends StatelessWidget {
  const _PrimaryMetrics({required this.statistics});

  final SleepStatistics statistics;

  @override
  Widget build(BuildContext context) {
    final List<_Metric> metrics = <_Metric>[
      _Metric(
        'Sueño total',
        AppDateTimeUtils.formatMinutes(statistics.totalMinutes),
      ),
      _Metric('Diurno', AppDateTimeUtils.formatMinutes(statistics.dayMinutes)),
      _Metric(
        'Nocturno',
        AppDateTimeUtils.formatMinutes(statistics.nightMinutes),
      ),
      _Metric('Días con datos', statistics.daysWithDataCount.toString()),
    ];
    return _ResponsiveMetricLayout(metrics: metrics, prominent: true);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Icon(icon),
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[child],
      ),
    );
  }
}

class _SectionMetrics extends StatelessWidget {
  const _SectionMetrics({required this.metrics, this.message});

  final List<_Metric> metrics;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (message != null) ...<Widget>[
          Text(message!),
          const SizedBox(height: 12),
        ],
        _ResponsiveMetricLayout(metrics: metrics),
      ],
    );
  }
}

class _ResponsiveMetricLayout extends StatelessWidget {
  const _ResponsiveMetricLayout({
    required this.metrics,
    this.prominent = false,
  });

  final List<_Metric> metrics;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double scale = MediaQuery.textScalerOf(context).scale(1);
        final int columns = constraints.maxWidth < 500 || scale >= 1.3 ? 1 : 2;
        final double width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            for (final _Metric metric in metrics)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        metric.label,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        metric.value,
                        style: prominent
                            ? Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              )
                            : Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class DailySleepChart extends StatelessWidget {
  const DailySleepChart({required this.data, super.key});

  final List<DailySleepTotal> data;

  @override
  Widget build(BuildContext context) {
    final List<DailySleepTotal> visible = data.length > 7
        ? data.sublist(data.length - 7)
        : data;
    if (visible.isEmpty ||
        visible.every((DailySleepTotal item) => !item.hasData)) {
      return const Center(
        key: Key('daily-chart-no-data'),
        child: Text('Sin registros para este período.'),
      );
    }
    final double maxHours = math.max(
      1,
      visible
              .where((DailySleepTotal item) => item.hasData)
              .map((DailySleepTotal item) => item.totalMinutes / 60)
              .fold<double>(0, math.max) +
          1,
    );
    final Color dayColor = Theme.of(context).colorScheme.tertiary;
    final Color nightColor = Theme.of(context).colorScheme.primary;
    return BarChart(
      BarChartData(
        maxY: maxHours,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final DailySleepTotal item = visible[group.x];
              if (!item.hasData) {
                return BarTooltipItem(
                  'Sin datos',
                  Theme.of(context).textTheme.bodyMedium!,
                );
              }
              return BarTooltipItem(
                '${DateFormat('dd/MM').format(item.localDate)}\n'
                'Diurno: ${AppDateTimeUtils.formatMinutes(item.dayMinutes)}\n'
                'Nocturno: ${AppDateTimeUtils.formatMinutes(item.nightMinutes)}',
                Theme.of(context).textTheme.bodyMedium!,
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: const Text('Horas'),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (double value, TitleMeta meta) => Text(
                '${value.toInt()} h',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int index = value.toInt();
                if (index < 0 || index >= visible.length) {
                  return const SizedBox.shrink();
                }
                if (visible.length > 4 && index.isOdd) {
                  return const SizedBox(height: 28);
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('dd/MM').format(visible[index].localDate),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
              reservedSize: 32,
            ),
          ),
        ),
        barGroups: <BarChartGroupData>[
          for (int index = 0; index < visible.length; index += 1)
            BarChartGroupData(
              x: index,
              barRods: <BarChartRodData>[
                if (visible[index].hasData)
                  BarChartRodData(
                    toY: visible[index].totalMinutes / 60,
                    width: 18,
                    borderRadius: BorderRadius.circular(5),
                    rodStackItems: <BarChartRodStackItem>[
                      BarChartRodStackItem(
                        0,
                        visible[index].dayMinutes / 60,
                        dayColor,
                      ),
                      BarChartRodStackItem(
                        visible[index].dayMinutes / 60,
                        visible[index].totalMinutes / 60,
                        nightColor,
                      ),
                    ],
                  )
                else
                  BarChartRodData(
                    toY: 0.01,
                    width: 8,
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DistributionBar extends StatelessWidget {
  const _DistributionBar({
    required this.dayMinutes,
    required this.nightMinutes,
  });

  final double dayMinutes;
  final double nightMinutes;

  @override
  Widget build(BuildContext context) {
    final double total = dayMinutes + nightMinutes;
    if (total <= 0) {
      return const Text('Sin datos para distribuir.');
    }
    final int dayFlex = math.max(1, (dayMinutes / total * 1000).round());
    final int nightFlex = math.max(1, 1000 - dayFlex);
    final Color dayColor = Theme.of(context).colorScheme.tertiary;
    final Color nightColor = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Distribución diurna y nocturna',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 22,
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: dayFlex,
                  child: ColoredBox(color: dayColor),
                ),
                Expanded(
                  flex: nightFlex,
                  child: ColoredBox(color: nightColor),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: <Widget>[
            _DistributionLegend(
              color: dayColor,
              label: 'Diurno',
              percentage: dayMinutes / total,
              minutes: dayMinutes,
            ),
            _DistributionLegend(
              color: nightColor,
              label: 'Nocturno',
              percentage: nightMinutes / total,
              minutes: nightMinutes,
            ),
          ],
        ),
      ],
    );
  }
}

class _DistributionLegend extends StatelessWidget {
  const _DistributionLegend({
    required this.color,
    required this.label,
    required this.percentage,
    required this.minutes,
  });

  final Color color;
  final String label;
  final double percentage;
  final double minutes;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ${(percentage * 100).round()}% · '
          '${AppDateTimeUtils.formatMinutes(minutes)}',
        ),
      ],
    );
  }
}

class _AwakeLineChart extends StatelessWidget {
  const _AwakeLineChart({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final List<double> visible = values.length > 20
        ? values.sublist(values.length - 20)
        : values;
    return LineChart(
      LineChartData(
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (List<LineBarSpot> spots) => spots
                .map(
                  (LineBarSpot spot) => LineTooltipItem(
                    AppDateTimeUtils.formatMinutes(spot.y),
                    Theme.of(context).textTheme.bodyMedium!,
                  ),
                )
                .toList(growable: false),
          ),
        ),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            axisNameWidget: Text('Minutos'),
            sideTitles: SideTitles(showTitles: true, reservedSize: 42),
          ),
        ),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: <FlSpot>[
              for (int index = 0; index < visible.length; index += 1)
                FlSpot(index.toDouble(), visible[index]),
            ],
            isCurved: false,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value);

  final String label;
  final String value;
}
