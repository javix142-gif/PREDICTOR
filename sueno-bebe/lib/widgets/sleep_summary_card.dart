import 'package:flutter/material.dart';

import '../models/sleep_statistics.dart';
import '../utils/date_time_utils.dart';

class SleepSummaryCard extends StatelessWidget {
  const SleepSummaryCard({
    required this.statistics,
    required this.rangeLabel,
    required this.statusLabel,
    required this.isHighlyVariableAge,
    super.key,
  });

  final SleepStatistics? statistics;
  final String rangeLabel;
  final String statusLabel;
  final bool isHighlyVariableAge;

  @override
  Widget build(BuildContext context) {
    final SleepStatistics? value = statistics;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Sueño en las últimas 24 horas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              AppDateTimeUtils.formatMinutes(value?.totalMinutes),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(statusLabel),
            Text('Referencia general: $rangeLabel, incluyendo siestas.'),
            const SizedBox(height: 6),
            const Text(
              'Un solo período no permite concluir que exista un problema de sueño.',
            ),
            const Divider(height: 28),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Part(
                    label: 'Diurno',
                    value: AppDateTimeUtils.formatMinutes(value?.dayMinutes),
                  ),
                ),
                Expanded(
                  child: _Part(
                    label: 'Nocturno',
                    value: AppDateTimeUtils.formatMinutes(value?.nightMinutes),
                  ),
                ),
              ],
            ),
            if (isHighlyVariableAge) ...<Widget>[
              const SizedBox(height: 12),
              const Text(
                'En menores de 4 meses los patrones pueden ser fragmentados y variables.',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(value),
      ],
    );
  }
}
