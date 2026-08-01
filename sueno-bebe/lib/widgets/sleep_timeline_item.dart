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
    super.key,
  });

  final SleepEvent event;
  final String timezone;
  final DateTime nowUtc;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final String end = event.endUtc == null
        ? 'En curso'
        : AppDateTimeUtils.formatTime(event.endUtc!, timezone);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Icon(
          event.type == SleepType.nap
              ? Icons.light_mode_outlined
              : Icons.dark_mode_outlined,
        ),
        title: Text(event.type.label),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${AppDateTimeUtils.formatTime(event.startUtc, timezone)} – $end · '
              '${AppDateTimeUtils.formatDuration(event.durationAt(nowUtc))}',
            ),
            Text('${event.accuracy.label} · ${event.origin.label}'),
            if (event.notes?.isNotEmpty ?? false) Text(event.notes!),
          ],
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Opciones del registro',
          onSelected: (String value) {
            if (value == 'edit') {
              onEdit();
            } else {
              onDelete();
            }
          },
          itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
            PopupMenuItem<String>(value: 'edit', child: Text('Editar')),
            PopupMenuItem<String>(value: 'delete', child: Text('Eliminar')),
          ],
        ),
      ),
    );
  }
}
