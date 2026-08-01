import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../models/baby_profile.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  late DateTime _birthDate;
  DateTime? _expectedDueDate;

  @override
  void initState() {
    super.initState();
    final BabyProfile profile = context.read<AppController>().profile!;
    _nameController = TextEditingController(text: profile.name);
    _notesController = TextEditingController(text: profile.notes ?? '');
    _birthDate = profile.birthDate;
    _expectedDueDate = profile.expectedDueDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppController controller = context.watch<AppController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre o apodo'),
              validator: (String? value) =>
                  value == null || value.trim().isEmpty
                  ? 'Campo obligatorio.'
                  : null,
            ),
            const SizedBox(height: 16),
            _DateTile(
              label: 'Fecha de nacimiento',
              value: _birthDate,
              onTap: () => _pickDate(isBirth: true),
            ),
            const SizedBox(height: 16),
            _DateTile(
              label: 'Fecha probable de parto',
              value: _expectedDueDate,
              onTap: () => _pickDate(isBirth: false),
              onClear: _expectedDueDate == null
                  ? null
                  : () => setState(() => _expectedDueDate = null),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Observación (opcional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: controller.isBusy ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isBirth}) async {
    final DateTime now = DateTime.now();
    final DateTime initial = isBirth
        ? _birthDate
        : _expectedDueDate ?? _birthDate;
    final DateTime? result = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 3),
      lastDate: isBirth ? now : DateTime(now.year + 1),
    );
    if (result != null) {
      setState(() {
        if (isBirth) {
          _birthDate = result;
        } else {
          _expectedDueDate = result;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    try {
      await context.read<AppController>().updateProfile(
        name: _nameController.text,
        birthDate: _birthDate,
        expectedDueDate: _expectedDueDate,
        notes: _notesController.text,
      );
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

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(16),
      ),
      leading: const Icon(Icons.calendar_month_rounded),
      title: Text(label),
      subtitle: Text(
        value == null
            ? 'No informada'
            : '${value!.day.toString().padLeft(2, '0')}/'
                  '${value!.month.toString().padLeft(2, '0')}/${value!.year}',
      ),
      onTap: onTap,
      trailing: onClear == null
          ? null
          : IconButton(
              tooltip: 'Quitar fecha',
              onPressed: onClear,
              icon: const Icon(Icons.clear_rounded),
            ),
    );
  }
}
