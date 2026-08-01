import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

import '../controllers/app_controller.dart';
import '../models/sleep_event.dart';
import '../utils/date_time_utils.dart';
import '../widgets/empty_state.dart';
import '../widgets/sleep_timeline_item.dart';
import 'sleep_event_form_screen.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final AppController controller = context.watch<AppController>();
    final List<SleepEvent> events = controller.events.reversed
        .where((SleepEvent event) {
          if (_selectedDate == null) {
            return true;
          }
          final tz.TZDateTime local = tz.TZDateTime.from(
            event.startUtc,
            controller.location,
          );
          return local.year == _selectedDate!.year &&
              local.month == _selectedDate!.month &&
              local.day == _selectedDate!.day;
        })
        .toList(growable: false);

    return Stack(
      children: <Widget>[
        Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDate(context),
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: Text(
                        _selectedDate == null
                            ? 'Todas las fechas'
                            : '${_selectedDate!.day.toString().padLeft(2, '0')}/'
                                  '${_selectedDate!.month.toString().padLeft(2, '0')}/'
                                  '${_selectedDate!.year}',
                      ),
                    ),
                  ),
                  if (_selectedDate != null) ...<Widget>[
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Quitar filtro',
                      onPressed: () => setState(() => _selectedDate = null),
                      icon: const Icon(Icons.clear_rounded),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: events.isEmpty
                  ? EmptyState(
                      icon: Icons.history_toggle_off_rounded,
                      title: 'No hay registros',
                      message: _selectedDate == null
                          ? 'Inicia un sueño desde Hoy o agrega uno manualmente.'
                          : 'No existen eventos para la fecha seleccionada.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                      children: _groupedTimeline(
                        context: context,
                        controller: controller,
                        events: events,
                      ),
                    ),
            ),
          ],
        ),
        Positioned(
          right: 18,
          bottom: 18,
          child: FloatingActionButton.extended(
            heroTag: 'add-sleep-event',
            onPressed: () => _openForm(context, null),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar'),
          ),
        ),
      ],
    );
  }

  List<Widget> _groupedTimeline({
    required BuildContext context,
    required AppController controller,
    required List<SleepEvent> events,
  }) {
    final List<Widget> children = <Widget>[];
    String? previousDateKey;
    for (final SleepEvent event in events) {
      final tz.TZDateTime local = tz.TZDateTime.from(
        event.startUtc,
        controller.location,
      );
      final String dateKey = '${local.year}-${local.month}-${local.day}';
      if (dateKey != previousDateKey) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
            child: Text(
              AppDateTimeUtils.formatDate(
                event.startUtc,
                controller.profile!.timezone,
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        );
        previousDateKey = dateKey;
      }
      children.add(
        SleepTimelineItem(
          event: event,
          timezone: controller.profile!.timezone,
          nowUtc: controller.nowUtc,
          onEdit: () => _openForm(context, event),
          onDelete: () => _confirmDelete(context, event),
        ),
      );
    }
    return children;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 730)),
      lastDate: now,
    );
    if (selected != null) {
      setState(() => _selectedDate = selected);
    }
  }

  Future<void> _openForm(BuildContext context, SleepEvent? event) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SleepEventFormScreen(event: event),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, SleepEvent event) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: const Text(
          'Este registro se eliminará de las estadísticas y predicciones futuras.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await context.read<AppController>().deleteEvent(event.id);
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}
