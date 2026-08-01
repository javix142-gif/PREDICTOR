import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  DateTime? _birthDate;
  DateTime? _expectedDueDate;
  AppThemePreference _theme = AppThemePreference.system;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppController controller = context.watch<AppController>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Icon(
                      Icons.nightlight_round,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Sueño Bebé',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Registra el sueño y obtén estimaciones transparentes basadas en los datos observados.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    if (controller.userMessage != null) ...<Widget>[
                      Card(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Icon(Icons.error_outline_rounded),
                              const SizedBox(width: 12),
                              Expanded(child: Text(controller.userMessage!)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre o apodo',
                        prefixIcon: Icon(Icons.child_care_rounded),
                      ),
                      validator: (String? value) =>
                          value == null || value.trim().isEmpty
                          ? 'Ingresa un nombre o apodo.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _DateField(
                      label: 'Fecha de nacimiento',
                      value: _birthDate,
                      onTap: () => _pickBirthDate(context),
                    ),
                    const SizedBox(height: 16),
                    _DateField(
                      label: 'Fecha probable de parto (opcional)',
                      value: _expectedDueDate,
                      onTap: () => _pickExpectedDate(context),
                      onClear: _expectedDueDate == null
                          ? null
                          : () => setState(() => _expectedDueDate = null),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<AppThemePreference>(
                      initialValue: _theme,
                      decoration: const InputDecoration(
                        labelText: 'Tema',
                        prefixIcon: Icon(Icons.contrast_rounded),
                      ),
                      items: const <DropdownMenuItem<AppThemePreference>>[
                        DropdownMenuItem<AppThemePreference>(
                          value: AppThemePreference.system,
                          child: Text('Automático'),
                        ),
                        DropdownMenuItem<AppThemePreference>(
                          value: AppThemePreference.light,
                          child: Text('Claro'),
                        ),
                        DropdownMenuItem<AppThemePreference>(
                          value: AppThemePreference.dark,
                          child: Text('Oscuro'),
                        ),
                      ],
                      onChanged: (AppThemePreference? value) {
                        if (value != null) {
                          setState(() => _theme = value);
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(Icons.info_outline_rounded),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Esta aplicación entrega orientación estadística '
                                'basada en los registros ingresados. No reemplaza '
                                'la evaluación de un profesional de salud.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: controller.isBusy ? null : _submit,
                      icon: controller.isBusy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Comenzar seguimiento'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickBirthDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      helpText: 'Fecha de nacimiento',
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _pickExpectedDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expectedDueDate ?? _birthDate ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      helpText: 'Fecha probable de parto',
    );
    if (picked != null) {
      setState(() => _expectedDueDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_birthDate == null) {
      _showError('Selecciona la fecha de nacimiento.');
      return;
    }
    try {
      await context.read<AppController>().createProfile(
        name: _nameController.text,
        birthDate: _birthDate!,
        expectedDueDate: _expectedDueDate,
        theme: _theme,
      );
    } on Object catch (error) {
      if (mounted) {
        _showError(error.toString());
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
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
    final String text = value == null
        ? 'Seleccionar'
        : '${value!.day.toString().padLeft(2, '0')}/'
              '${value!.month.toString().padLeft(2, '0')}/${value!.year}';
    return Semantics(
      button: true,
      label: '$label: $text',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_month_rounded),
            suffixIcon: onClear == null
                ? const Icon(Icons.arrow_drop_down_rounded)
                : IconButton(
                    tooltip: 'Quitar fecha',
                    onPressed: onClear,
                    icon: const Icon(Icons.clear_rounded),
                  ),
          ),
          child: Text(text),
        ),
      ),
    );
  }
}
