import 'package:flutter/material.dart';

import '../models/sleep_statistics.dart';
import '../utils/date_time_utils.dart';

class SleepSummaryCard extends StatelessWidget {
  const SleepSummaryCard({
    required this.statistics,
    required this.rangeLabel,
    required this.statusLabel,
    required this.showRangeComparison,
    required this.isHighlyVariableAge,
    super.key,
  });

  final SleepStatistics? statistics;
  final String rangeLabel;
  final String statusLabel;
  final bool showRangeComparison;
  final bool isHighlyVariableAge;

  @override
  Widget build(BuildContext context) {
    final SleepStatistics? value = statistics;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Resumen de 24 horas',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppDateTimeUtils.formatMinutes(value?.totalMinutes),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  showRangeComparison
                      ? Icons.check_circle_outline_rounded
                      : Icons.hourglass_bottom_rounded,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(statusLabel)),
              ],
            ),
            if (showRangeComparison) ...<Widget>[
              const SizedBox(height: 6),
              Text('Referencia general: $rangeLabel, incluyendo siestas.'),
            ],
            const Divider(height: 26),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: <Widget>[
                _Part(
                  label: 'Diurno',
                  value: AppDateTimeUtils.formatMinutes(value?.dayMinutes),
                ),
                _Part(
                  label: 'Nocturno',
                  value: AppDateTimeUtils.formatMinutes(value?.nightMinutes),
                ),
              ],
            ),
            if (isHighlyVariableAge) ...<Widget>[
              const SizedBox(height: 12),
              const Text(
                'En menores de 4 meses los patrones suelen ser fragmentados y variables.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Part extends StatelessWidget {
  const _Part({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 3),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
