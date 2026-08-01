import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import 'limitations_screen.dart';
import 'privacy_screen.dart';
import 'profile_edit_screen.dart';
import 'safe_sleep_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppController controller = context.watch<AppController>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: <Widget>[
        _Section(
          title: 'Perfil',
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.child_care_rounded),
              title: Text(controller.profile!.name),
              subtitle: Text('Zona horaria: ${controller.profile!.timezone}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const ProfileEditScreen(),
                ),
              ),
            ),
          ],
        ),
        _Section(
          title: 'Apariencia',
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.contrast_rounded),
              title: const Text('Tema'),
              trailing: DropdownButton<AppThemePreference>(
                value: controller.themePreference,
                underline: const SizedBox.shrink(),
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
                    controller.setThemePreference(value);
                  }
                },
              ),
            ),
          ],
        ),
        _Section(
          title: 'Notificaciones',
          children: <Widget>[
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Recordatorios de ventana'),
              subtitle: const Text(
                'Se solicitará permiso antes de activarlos. La hora es aproximada.',
              ),
              value: controller.notificationsEnabled,
              onChanged: (bool value) =>
                  _changeNotifications(context, controller, value),
            ),
            ListTile(
              enabled: controller.notificationsEnabled,
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('Anticipación'),
              trailing: DropdownButton<int>(
                value: controller.notificationAdvanceMinutes,
                underline: const SizedBox.shrink(),
                items: const <DropdownMenuItem<int>>[
                  DropdownMenuItem<int>(value: 0, child: Text('Al inicio')),
                  DropdownMenuItem<int>(value: 10, child: Text('10 min')),
                  DropdownMenuItem<int>(value: 15, child: Text('15 min')),
                  DropdownMenuItem<int>(value: 30, child: Text('30 min')),
                ],
                onChanged: controller.notificationsEnabled
                    ? (int? value) {
                        if (value != null) {
                          controller.setNotificationAdvance(value);
                        }
                      }
                    : null,
              ),
            ),
          ],
        ),
        _Section(
          title: 'Datos',
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('Exportar datos CSV'),
              subtitle: const Text('Incluye perfil, eventos y predicciones.'),
              onTap: controller.isBusy
                  ? null
                  : () => _export(context, controller),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Eliminar todos los datos',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: controller.isBusy
                  ? null
                  : () => _confirmDeleteAll(context, controller),
            ),
          ],
        ),
        _Section(
          title: 'Información',
          children: <Widget>[
            _RouteTile(
              icon: Icons.shield_outlined,
              title: 'Privacidad',
              screen: const PrivacyScreen(),
            ),
            _RouteTile(
              icon: Icons.bedroom_baby_outlined,
              title: 'Sueño seguro',
              screen: const SafeSleepScreen(),
            ),
            _RouteTile(
              icon: Icons.info_outline_rounded,
              title: 'Limitaciones de la aplicación',
              screen: const LimitationsScreen(),
            ),
            const ListTile(
              leading: Icon(Icons.code_rounded),
              title: Text('Versión'),
              trailing: Text('1.0.0'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _changeNotifications(
    BuildContext context,
    AppController controller,
    bool value,
  ) async {
    try {
      if (!value) {
        await controller.setNotificationsEnabled(false);
        return;
      }
      final bool? accepted = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Activar notificaciones'),
          content: const Text(
            'Android o iOS solicitará permiso para mostrar recordatorios '
            'locales. No se solicitarán ubicación ni alarmas exactas.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (accepted != true || !context.mounted) {
        return;
      }
      final bool granted = await controller.enableNotificationsWithPermission();
      if (!granted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El permiso fue rechazado. Puedes activarlo desde los ajustes del sistema.',
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        _showError(context, error.toString());
      }
    }
  }

  Future<void> _export(BuildContext context, AppController controller) async {
    try {
      final File file = await controller.exportData();
      await controller.shareExport(file);
    } on Object catch (error) {
      if (context.mounted) {
        _showError(context, error.toString());
      }
    }
  }

  Future<void> _confirmDeleteAll(
    BuildContext context,
    AppController controller,
  ) async {
    final TextEditingController confirmation = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Eliminar todos los datos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Esta acción elimina el perfil, eventos, estadísticas y '
              'predicciones del dispositivo. No se puede deshacer.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmation,
              decoration: const InputDecoration(
                labelText: 'Escribe ELIMINAR para confirmar',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              confirmation.text.trim().toUpperCase() == 'ELIMINAR',
            ),
            child: const Text('Eliminar definitivamente'),
          ),
        ],
      ),
    );
    confirmation.dispose();
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await controller.deleteAllData();
    } on Object catch (error) {
      if (context.mounted) {
        _showError(context, error.toString());
      }
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({
    required this.icon,
    required this.title,
    required this.screen,
  });

  final IconData icon;
  final String title;
  final Widget screen;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(
        context,
      ).push<void>(MaterialPageRoute<void>(builder: (_) => screen)),
    );
  }
}
