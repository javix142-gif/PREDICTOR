import 'package:flutter/material.dart';

import '../models/sleep_event.dart';
import '../utils/date_time_utils.dart';

class CurrentStatusCard extends StatelessWidget {
  const CurrentStatusCard({
    required this.openEvent,
    required this.lastCompletedEvent,
    required this.nowUtc,
    required this.isNightAwakening,
    super.key,
  });

  final SleepEvent? openEvent;
  final SleepEvent? lastCompletedEvent;
  final DateTime nowUtc;
  final bool isNightAwakening;

  @override
  Widget build(BuildContext context) {
    final bool sleeping = openEvent != null;
    final DateTime? reference = sleeping
        ? openEvent!.startUtc
        : lastCompletedEvent?.endUtc;
    final Duration? elapsed = reference == null
        ? null
        : nowUtc.toUtc().difference(reference.toUtc());
    final String stateLabel = sleeping
        ? 'Durmiendo'
        : isNightAwakening
        ? 'Despertar nocturno'
        : 'Despierta';
    final IconData icon = sleeping
        ? Icons.bedtime_rounded
        : isNightAwakening
        ? Icons.nights_stay_rounded
        : Icons.wb_sunny_rounded;
    final String elapsedLabel = elapsed == null
        ? 'Sin un despertar registrado'
        : sleeping
        ? 'Tiempo dormida'
        : 'Tiempo despierta';

    return Semantics(
      container: true,
      label: '$stateLabel. $elapsedLabel ${elapsed == null ? '' : AppDateTimeUtils.formatDuration(elapsed)}',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      stateLabel,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (sleeping)
                    Chip(
                      avatar: Icon(
                        openEvent!.type == SleepType.nap
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        size: 18,
                      ),
                      label: Text(openEvent!.type.label),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(elapsedLabel, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(
                elapsed == null
                    ? '—'
                    : AppDateTimeUtils.formatDuration(elapsed),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
              if (isNightAwakening) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'El último segmento fue nocturno. Decide si continúa la misma noche o si ya terminó.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
