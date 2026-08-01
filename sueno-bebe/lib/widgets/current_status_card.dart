import 'package:flutter/material.dart';

import '../models/sleep_event.dart';
import '../utils/date_time_utils.dart';

class CurrentStatusCard extends StatelessWidget {
  const CurrentStatusCard({
    required this.openEvent,
    required this.lastCompletedEvent,
    required this.nowUtc,
    super.key,
  });

  final SleepEvent? openEvent;
  final SleepEvent? lastCompletedEvent;
  final DateTime nowUtc;

  @override
  Widget build(BuildContext context) {
    final bool sleeping = openEvent != null;
    final DateTime? reference = sleeping
        ? openEvent!.startUtc
        : lastCompletedEvent?.endUtc;
    final Duration? elapsed = reference == null
        ? null
        : nowUtc.toUtc().difference(reference.toUtc());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 27,
              child: Icon(sleeping ? Icons.bedtime_rounded : Icons.wb_sunny_rounded),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    sleeping ? 'Durmiendo' : 'Despierto',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    elapsed == null
                        ? 'Aún no hay un despertar registrado'
                        : sleeping
                            ? 'Desde hace ${AppDateTimeUtils.formatDuration(elapsed)}'
                            : 'Desde hace ${AppDateTimeUtils.formatDuration(elapsed)}',
                  ),
                  if (sleeping) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      openEvent!.type.label,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
