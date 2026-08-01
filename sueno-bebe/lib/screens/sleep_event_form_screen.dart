import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../controllers/app_controller.dart';
import '../models/sleep_event.dart';
import '../utils/date_time_utils.dart';

class SleepEventFormScreen extends StatefulWidget {
  const SleepEventFormScreen({this.event, super.key});

  final SleepEvent? event;

  @override
  State<SleepEventFormScreen> createState() => _SleepEventFormScreenState();
}

class _SleepEventFormScreenState extends State<SleepEventFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  late DateTime _startLocal;
  DateTime? _endLocal;
  late SleepType _type;
  late SleepAccuracy _accuracy;

  @override
  void initState() {
    super.initState();
    final AppController controller = context.read<AppController>();
    final SleepEvent? event = widget.event;
    final tz.Location location = controller.location;
    final tz.TZDateTime nowLocal = tz.TZDateTime.from(
      controller.nowUtc,
      location,
    );
    if (event == null) {
      _endLocal = DateTime(
        nowLocal.year,
        nowLocal.month,
        nowLocal.day,
        nowLocal.hour,
        nowLocal.minute,
      );
      _startLocal = _endLocal!.subtract(const Duration(hours: 1));
      _type = controller.suggestedSleepType();
      _accuracy = SleepAccuracy.exact;
    } else {
      final tz.TZDateTime start = tz.TZDateTime.from(event.startUtc, location);
      _startLocal = DateTime(
        start.year,
        start.month,
        start.day,
        start.hour,
        start.minute,
      );
      if (event.endUtc != null) {
        final tz.TZDateTime end = tz.TZDateTime.from(event.endUtc!, location);
        _endLocal = DateTime(
          end.year,
          end.month,
          end.day,
          end.hour,
          end.minute,
        );
      }
      _type = event.type;
      _accuracy = event.accuracy;
      _notesController.text = event.notes ?? '';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isOpen = widget.event?.isOpen ?? false;
    final AppController controller = context.watch<AppController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event == null ? 'Agregar sueño' : 'Editar sueño'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            DropdownButtonFormField<SleepType>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                prefixIcon: Icon(Icons.bedtime_outlined),
              ),
              items: SleepType.values
                  .map(
                    (SleepType item) => DropdownMenuItem<SleepType>(
                      value: item,
                      child: Text(item.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (SleepType? value) {
                if (value != null) {
                  setState(() => _type = value);
                }
              },
            ),
            const SizedBox(height: 16),
            _DateTimeField(
              label: 'Inicio',
              value: _startLocal,
              onTap: () => _pickDateTime(isStart: true),
            ),
            const SizedBox(height: 16),
            if (isOpen)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.timer_outlined),
                  title: Text('Registro abierto'),
                  subtitle: Text(
                    'El término se completa al usar “Finalizar sueño” en Hoy.',
                  ),
                ),
              )
            else
              _DateTimeField(
                label: 'Término',
                value: _endLocal!,
                onTap: () => _pickDateTime(isStart: false),
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<SleepAccuracy>(
              initialValue: _accuracy,
              decoration: const InputDecoration(
                labelText: 'Precisión',
                prefixIcon: Icon(Icons.tune_rounded),
              ),
              items: SleepAccuracy.values
                  .map(
                    (SleepAccuracy item) => DropdownMenuItem<SleepAccuracy>(
                      value: item,
                      child: Text(item.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (SleepAccuracy? value) {
                if (value != null) {
                  setState(() => _accuracy = value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Observación (opcional)',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: controller.isBusy ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Guardar registro'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final DateTime initial = isStart ? _startLocal : _endLocal!;
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 730)),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (date == null || !mounted) {
      return;
    }
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return;
    }
    final DateTime value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        _startLocal = value;
      } else {
        _endLocal = value;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final AppController controller = context.read<AppController>();
    final String timezone = controller.profile!.timezone;
    final DateTime startUtc = AppDateTimeUtils.localWallClockToUtc(
      _startLocal,
      timezone,
    );
    final DateTime? endUtc = widget.event?.isOpen ?? false
        ? null
        : AppDateTimeUtils.localWallClockToUtc(_endLocal!, timezone);
    final DateTime now = controller.nowUtc;
    final SleepEvent? existing = widget.event;
    final SleepEvent event = SleepEvent(
      id: existing?.id ?? const Uuid().v4(),
      babyId: controller.profile!.id,
      startUtc: startUtc,
      endUtc: endUtc,
      type: _type,
      accuracy: _accuracy,
      origin: existing?.origin ?? SleepOrigin.manual,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      timezone: timezone,
      createdAtUtc: existing?.createdAtUtc ?? now,
      modifiedAtUtc: now,
    );
    try {
      await controller.saveManualEvent(event);
      if (mounted) {
        Navigator.pop(context);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String text =
        '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/${value.year} · '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
    return Semantics(
      button: true,
      label: '$label: $text',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.event_rounded),
            suffixIcon: const Icon(Icons.edit_calendar_rounded),
          ),
          child: Text(text),
        ),
      ),
    );
  }
}
