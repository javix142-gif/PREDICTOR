import 'package:flutter/material.dart';

import '../models/sleep_prediction.dart';
import '../utils/date_time_utils.dart';

class PredictionCard extends StatelessWidget {
  const PredictionCard({
    required this.prediction,
    required this.timezone,
    required this.onDetails,
    super.key,
  });

  final SleepPrediction? prediction;
  final String timezone;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final SleepPrediction? value = prediction;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: value == null
            ? const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Próxima ventana orientativa'),
                  SizedBox(height: 8),
                  Text(
                    'Se necesita al menos un sueño finalizado para calcularla.',
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Próxima ventana orientativa',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Chip(label: Text('Confianza ${value.confidence.label}')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${AppDateTimeUtils.formatTime(value.windowStartUtc, timezone)} '
                    '– ${AppDateTimeUtils.formatTime(value.windowEndUtc, timezone)}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Momento central: '
                    '${AppDateTimeUtils.formatTime(value.centerUtc, timezone)} · '
                    '${value.intendedType.label}',
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onDetails,
                      icon: const Icon(Icons.info_outline_rounded),
                      label: const Text('Cómo se calculó'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
