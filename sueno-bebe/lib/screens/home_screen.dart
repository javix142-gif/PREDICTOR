import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

import '../controllers/app_controller.dart';
import '../models/baby_profile.dart';
import '../models/sleep_event.dart';
import '../utils/date_time_utils.dart';
import '../widgets/current_status_card.dart';
import '../widgets/prediction_card.dart';
import '../widgets/sleep_summary_card.dart';
import 'prediction_details_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'timeline_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const List<String> _titles = <String>[
    'Hoy',
    'Historial',
    'Estadísticas',
    'Ajustes',
  ];

  @override
  Widget build(BuildContext context) {
    final AppController controller = context.watch<AppController>();
    final List<Widget> pages = <Widget>[
      const _TodayContent(),
      const TimelineScreen(),
      const StatisticsScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: controller.isBusy
            ? const <Widget>[
                Padding(
                  padding: EdgeInsets.only(right: 18),
                  child: Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) => setState(() => _index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today_rounded),
            label: 'Hoy',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Estadísticas',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}

class _TodayContent extends StatelessWidget {
  const _TodayContent();

  @override
  Widget build(BuildContext context) {
    final AppController controller = context.watch<AppController>();
    final BabyProfile profile = controller.profile!;
    final tz.TZDateTime localNow =
        tz.TZDateTime.from(controller.nowUtc, controller.location);
    final SleepEvent? lastCompleted = controller.events
        .where((SleepEvent event) => event.endUtc != null)
        .fold<SleepEvent?>(null, (SleepEvent? latest, SleepEvent event) {
      return latest == null || event.endUtc!.isAfter(latest.endUtc!)
          ? event
          : latest;
    });
    final bool underFourMonths =
        AppDateTimeUtils.ageInMonths(profile.birthDate, localNow) < 4;
    final range = controller.currentSleepAmountReference();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        Text(
          '${profile.name} · '
          '${AppDateTimeUtils.approximateAge(profile.birthDate, localNow)}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(AppDateTimeUtils.formatDate(controller.nowUtc, profile.timezone)),
        const SizedBox(height: 16),
        CurrentStatusCard(
          openEvent: controller.openEvent,
          lastCompletedEvent: lastCompleted,
          nowUtc: controller.nowUtc,
        ),
        const SizedBox(height: 12),
        Semantics(
          button: true,
          label: controller.openEvent == null
              ? 'Iniciar sueño'
              : 'Finalizar sueño',
          child: FilledButton.icon(
            onPressed: controller.isBusy
                ? null
                : controller.openEvent == null
                    ? () => _startSleep(context, controller)
                    : () => _finishSleep(context, controller),
            icon: Icon(
              controller.openEvent == null
                  ? Icons.play_arrow_rounded
                  : Icons.stop_rounded,
            ),
            label: Text(
              controller.openEvent == null ? 'Iniciar sueño' : 'Finalizar sueño',
            ),
          ),
        ),
        const SizedBox(height: 12),
        PredictionCard(
          prediction: controller.currentPrediction,
          timezone: profile.timezone,
          onDetails: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const PredictionDetailsScreen(),
              ),
            );
          },
        ),
        if (controller.bedtimeEstimate != null) ...<Widget>[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(18),
              leading: const Icon(Icons.bedtime_outlined),
              title: const Text('Inicio nocturno probable'),
              subtitle: Text(
                '${AppDateTimeUtils.formatTime(controller.bedtimeEstimate!.windowStartUtc, profile.timezone)} '
                '– ${AppDateTimeUtils.formatTime(controller.bedtimeEstimate!.windowEndUtc, profile.timezone)}\n'
                '${controller.bedtimeEstimate!.explanation}',
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        SleepSummaryCard(
          statistics: controller.rolling24Hours,
          rangeLabel: range == null
              ? 'Sin referencia disponible'
              : '${range.minimumHours} a ${range.maximumHours} horas',
          statusLabel: controller.sleepRangeStatus(),
          isHighlyVariableAge: underFourMonths,
        ),
      ],
    );
  }

  Future<void> _startSleep(
    BuildContext context,
    AppController controller,
  ) async {
    final SleepType suggested = controller.suggestedSleepType();
    final SleepType? selected = await showModalBottomSheet<SleepType>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  '¿Qué tipo de sueño comienza?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                for (final SleepType type in SleepType.values)
                  ListTile(
                    leading: Icon(
                      type == SleepType.nap
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                    title: Text(type.label),
                    subtitle: type == suggested
                        ? const Text('Sugerido según el horario')
                        : null,
                    trailing: type == suggested
                        ? const Icon(Icons.auto_awesome_rounded)
                        : null,
                    onTap: () => Navigator.pop(context, type),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || !context.mounted) {
      return;
    }
    try {
      await controller.startSleep(type: selected);
    } on Object catch (error) {
      if (context.mounted) {
        _showError(context, error.toString());
      }
    }
  }

  Future<void> _finishSleep(
    BuildContext context,
    AppController controller,
  ) async {
    try {
      await controller.finishSleep();
    } on Object catch (error) {
      if (context.mounted) {
        _showError(context, error.toString());
      }
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
