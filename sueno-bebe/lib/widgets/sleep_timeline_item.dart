import 'package:flutter/material.dart';

import '../models/sleep_event.dart';
import '../utils/date_time_utils.dart';

class SleepTimelineItem extends StatelessWidget {
  const SleepTimelineItem({
    required this.event,
    required this.timezone,
    required this.nowUtc,
    required this.onEdit,
    required this.onDelete,
    this.isNightContinuation = false,
    super.key,
  });

  final SleepEvent event;
  final String timezone;
  final DateTime nowUtc;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isNightContinuation;

  @override
  Widget build(BuildContext context) {
    final String end = event.endUtc == null
        ? 'En curso'
        : AppDateTimeUtils.formatTime(event.endUtc!, timezone);
    final String duration = AppDateTimeUtils.formatDuration(
      event.durationAt(nowUtc),
    );
    return Padding(
      padding: EdgeInsets.only(left: isNightContinuation ? 18 : 0, bottom: 8),
      child: Semantics(
        container: true,
        label:
            '${event.type.label}, duración $duration, ${AppDateTimeUtils.formatTime(event.startUtc, timezone)} a $end',
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(
                    event.type == SleepType.nap
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        duration,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${AppDateTimeUtils.formatTime(event.startUtc, timezone)} – $end · ${event.type.label}',
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          _SmallChip(label: event.accuracy.label),
                          _SmallChip(label: event.origin.label),
                          if (isNightContinuation)
                            const _SmallChip(label: 'Misma noche'),
                        ],
                      ),
                      if (event.notes?.isNotEmpty ?? false) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          event.notes!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Opciones del registro',
                  onSelected: (String value) {
                    if (value == 'edit') {
                      onEdit();
                    } else {
                      onDelete();
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      const <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('Editar'),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('Eliminar'),
                        ),
                      ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
    );
  }
}
