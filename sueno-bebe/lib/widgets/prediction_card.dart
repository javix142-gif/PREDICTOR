import 'package:flutter/material.dart';

import '../models/sleep_prediction.dart';
import '../utils/date_time_utils.dart';

class PredictionCard extends StatelessWidget {
  const PredictionCard({
    required this.prediction,
    required this.timezone,
    required this.nowUtc,
    required this.onDetails,
    super.key,
  });

  final SleepPrediction? prediction;
  final String timezone;
  final DateTime nowUtc;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final SleepPrediction? value = prediction;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                  Text(
                    'Próxima acción',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _relativeWindow(value),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${AppDateTimeUtils.formatTime(value.windowStartUtc, timezone)} '
                    '– ${AppDateTimeUtils.formatTime(value.windowEndUtc, timezone)}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      Chip(
                        avatar: const Icon(Icons.insights_rounded, size: 18),
                        label: Text(
                          value.source == PredictionSource.age
                              ? 'Basada en edad'
                              : 'Basada en historial',
                        ),
                      ),
                      Chip(
                        avatar: const Icon(Icons.verified_outlined, size: 18),
                        label: Text('Confianza ${value.confidence.label}'),
                      ),
                      Chip(label: Text(value.intendedType.label)),
                    ],
                  ),
                  const SizedBox(height: 4),
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

  String _relativeWindow(SleepPrediction value) {
    final int startMinutes = value.windowStartUtc.difference(nowUtc).inMinutes;
    final int endMinutes = value.windowEndUtc.difference(nowUtc).inMinutes;
    if (endMinutes < 0) {
      return 'La ventana estimada ya comenzó';
    }
    final int safeStart = startMinutes < 0 ? 0 : startMinutes;
    return 'Faltan aproximadamente $safeStart–$endMinutes min';
  }
}
