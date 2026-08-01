import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../models/sleep_statistics.dart';
import '../utils/date_time_utils.dart';
import '../widgets/empty_state.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppController controller = context.watch<AppController>();
    final SleepStatistics? statistics = controller.selectedStatistics;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        SegmentedButton<int>(
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
        const SizedBox(height: 16),
        if (statistics == null || !statistics.hasSleepData)
          const EmptyState(
            icon: Icons.query_stats_rounded,
            title: 'Datos insuficientes',
            message: 'Registra sueños para calcular estadísticas y gráficos reales.',
          )
        else ...<Widget>[
          _MetricGrid(statistics: statistics),
          const SizedBox(height: 16),
          _ChartCard(
            title: 'Sueño total por día',
            child: _DailyBarChart(data: statistics.dailyTotals),
          ),
          const SizedBox(height: 12),
          _ChartCard(
            title: 'Distribución diurna y nocturna',
            child: _DistributionChart(
              dayMinutes: statistics.dayMinutes,
              nightMinutes: statistics.nightMinutes,
            ),
          ),
          const SizedBox(height: 12),
          _ChartCard(
            title: 'Duración de siestas',
            child: statistics.napDurationsMinutes.isEmpty
                ? const _NoChartData(message: 'No hay siestas en este período.')
                : _ValuesBarChart(values: statistics.napDurationsMinutes),
          ),
          const SizedBox(height: 12),
          _ChartCard(
            title: 'Ventanas despierto',
            child: statistics.awakeWindowsMinutes.isEmpty
                ? const _NoChartData(
                    message: 'Se necesitan sueños consecutivos finalizados.',
                  )
                : _AwakeLineChart(values: statistics.awakeWindowsMinutes),
          ),
        ],
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

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.statistics});

  final SleepStatistics statistics;

  @override
  Widget build(BuildContext context) {
    final List<(String, String)> metrics = <(String, String)>[
      ('Sueño total', AppDateTimeUtils.formatMinutes(statistics.totalMinutes)),
      ('Diurno', AppDateTimeUtils.formatMinutes(statistics.dayMinutes)),
      ('Nocturno', AppDateTimeUtils.formatMinutes(statistics.nightMinutes)),
      ('Número de siestas', statistics.napCount.toString()),
      ('Media de siestas', AppDateTimeUtils.formatMinutes(statistics.averageNapMinutes)),
      ('Mediana de siestas', AppDateTimeUtils.formatMinutes(statistics.medianNapMinutes)),
      ('Siesta más corta', AppDateTimeUtils.formatMinutes(statistics.shortestNapMinutes)),
      ('Siesta más larga', AppDateTimeUtils.formatMinutes(statistics.longestNapMinutes)),
      (
        'Sueño continuo más largo',
        AppDateTimeUtils.formatMinutes(statistics.longestContinuousSleepMinutes),
      ),
      (
        'Inicio nocturno mediano',
        _minuteOfDay(statistics.medianNightStartMinuteOfDay),
      ),
      ('Despertar mediano', _minuteOfDay(statistics.medianWakeMinuteOfDay)),
      (
        'Ventana despierto mediana',
        AppDateTimeUtils.formatMinutes(statistics.medianAwakeWindowMinutes),
      ),
      (
        'Ventana despierto mínima',
        AppDateTimeUtils.formatMinutes(statistics.minimumAwakeWindowMinutes),
      ),
      (
        'Ventana despierto máxima',
        AppDateTimeUtils.formatMinutes(statistics.maximumAwakeWindowMinutes),
      ),
      ('Rango intercuartílico', AppDateTimeUtils.formatMinutes(statistics.awakeWindowIqrMinutes)),
      ('Variabilidad entre días', AppDateTimeUtils.formatMinutes(statistics.dailyVariabilityMinutes)),
      ('Predicciones evaluables', statistics.evaluablePredictionCount.toString()),
      (
        'Error mediano de predicción',
        AppDateTimeUtils.formatMinutes(statistics.medianPredictionErrorMinutes),
      ),
    ];
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 620 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: 1.55,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (BuildContext context, int index) {
            final (String, String) metric = metrics[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(metric.$1, style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 6),
                    Text(metric.$2, style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _minuteOfDay(double? value) {
    if (value == null) {
      return 'Sin datos suficientes';
    }
    final int total = value.round() % (24 * 60);
    return '${(total ~/ 60).toString().padLeft(2, '0')}:'
        '${(total % 60).toString().padLeft(2, '0')}';
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(height: 220, child: child),
          ],
        ),
      ),
    );
  }
}

class _DailyBarChart extends StatelessWidget {
  const _DailyBarChart({required this.data});

  final List<DailySleepTotal> data;

  @override
  Widget build(BuildContext context) {
    final List<DailySleepTotal> visible = data.length > 14
        ? data.sublist(data.length - 14)
        : data;
    if (visible.every((DailySleepTotal item) => item.totalMinutes == 0)) {
      return const _NoChartData(message: 'No hay sueño registrado por día.');
    }
    final double maxHours = visible
            .map((DailySleepTotal item) => item.totalMinutes / 60)
            .fold<double>(0, math.max) +
        1;
    return BarChart(
      BarChartData(
        maxY: maxHours,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 34),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int index = value.toInt();
                if (index < 0 || index >= visible.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(DateFormat('dd/MM').format(visible[index].localDate)),
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
                BarChartRodData(
                  toY: visible[index].totalMinutes / 60,
                  width: 16,
                  borderRadius: BorderRadius.circular(5),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DistributionChart extends StatelessWidget {
  const _DistributionChart({required this.dayMinutes, required this.nightMinutes});

  final double dayMinutes;
  final double nightMinutes;

  @override
  Widget build(BuildContext context) {
    final double total = dayMinutes + nightMinutes;
    if (total <= 0) {
      return const _NoChartData(message: 'No hay datos para distribuir.');
    }
    return Row(
      children: <Widget>[
        Expanded(
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 38,
              sectionsSpace: 3,
              sections: <PieChartSectionData>[
                PieChartSectionData(
                  value: dayMinutes,
                  title: '${(dayMinutes / total * 100).round()}%',
                  color: Theme.of(context).colorScheme.secondary,
                  radius: 62,
                ),
                PieChartSectionData(
                  value: nightMinutes,
                  title: '${(nightMinutes / total * 100).round()}%',
                  color: Theme.of(context).colorScheme.primary,
                  radius: 62,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Legend(icon: Icons.light_mode_outlined, label: 'Sueño diurno'),
              SizedBox(height: 12),
              _Legend(icon: Icons.dark_mode_outlined, label: 'Sueño nocturno'),
            ],
          ),
        ),
      ],
    );
  }
}

class _ValuesBarChart extends StatelessWidget {
  const _ValuesBarChart({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final List<double> visible =
        values.length > 20 ? values.sublist(values.length - 20) : values;
    final double maxValue = visible.fold<double>(0, math.max) + 10;
    return BarChart(
      BarChartData(
        maxY: maxValue,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 38),
          ),
        ),
        barGroups: <BarChartGroupData>[
          for (int index = 0; index < visible.length; index += 1)
            BarChartGroupData(
              x: index,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: visible[index],
                  width: 10,
                  color: Theme.of(context).colorScheme.secondary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AwakeLineChart extends StatelessWidget {
  const _AwakeLineChart({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final List<double> visible =
        values.length > 30 ? values.sublist(values.length - 30) : values;
    return LineChart(
      LineChartData(
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
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

class _Legend extends StatelessWidget {
  const _Legend({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
      ],
    );
  }
}

class _NoChartData extends StatelessWidget {
  const _NoChartData({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message, textAlign: TextAlign.center));
  }
}
