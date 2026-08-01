import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../models/sleep_prediction.dart';
import '../utils/date_time_utils.dart';
import '../widgets/empty_state.dart';

class PredictionDetailsScreen extends StatelessWidget {
  const PredictionDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppController controller = context.watch<AppController>();
    final SleepPrediction? prediction = controller.currentPrediction;
    final String timezone = controller.profile?.timezone ?? 'UTC';
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de la predicción')),
      body: prediction == null
          ? const EmptyState(
              icon: Icons.insights_outlined,
              title: 'Sin predicción activa',
              message: 'Finaliza un sueño para calcular la próxima ventana.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${AppDateTimeUtils.formatTime(prediction.windowStartUtc, timezone)} '
                          '– ${AppDateTimeUtils.formatTime(prediction.windowEndUtc, timezone)}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Hora central: '
                          '${AppDateTimeUtils.formatTime(prediction.centerUtc, timezone)}',
                        ),
                        const SizedBox(height: 12),
                        Chip(
                          avatar: const Icon(Icons.verified_outlined, size: 18),
                          label: Text(
                            'Confianza ${prediction.confidence.label}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _DetailTile(
                  label: 'Registros utilizados',
                  value: prediction.observationCount.toString(),
                ),
                _DetailTile(
                  label: 'Mediana personal',
                  value: AppDateTimeUtils.formatMinutes(
                    prediction.medianMinutes,
                  ),
                ),
                _DetailTile(
                  label: 'Intervalo intercuartílico',
                  value: prediction.p25Minutes == null
                      ? 'Sin datos suficientes'
                      : '${AppDateTimeUtils.formatMinutes(prediction.p25Minutes)} – '
                            '${AppDateTimeUtils.formatMinutes(prediction.p75Minutes)}',
                ),
                _DetailTile(
                  label: 'Fuente principal',
                  value: prediction.source.label,
                ),
                _DetailTile(
                  label: 'Tipo probable',
                  value: prediction.intendedType.label,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Explicación',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(prediction.explanation),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.visibility_outlined),
                    title: Text('Observa también el comportamiento'),
                    subtitle: Text(
                      'La ventana es orientativa. Considera las señales de sueño '
                      'y el contexto del bebé; no indica que deba dormirse a una hora exacta.',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 190),
          child: Text(value, textAlign: TextAlign.end),
        ),
      ),
    );
  }
}
