import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

import '../controllers/app_controller.dart';
import '../models/baby_profile.dart';
import '../models/sleep_event.dart';
import '../models/tracking_coverage.dart';
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
      const TodayContent(),
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

class TodayContent extends StatelessWidget {
  const TodayContent({super.key});

  @override
  Widget build(BuildContext context) {
    final AppController controller = context.watch<AppController>();
    final BabyProfile profile = controller.profile!;
    final tz.TZDateTime localNow = tz.TZDateTime.from(
      controller.nowUtc,
      controller.location,
    );
    final bool sleeping = controller.openEvent != null;
    final bool nightAwakening = controller.isNightAwakening;
    final bool underFourMonths =
        AppDateTimeUtils.ageInMonths(profile.birthDate, localNow) < 4;
    final range = controller.currentSleepAmountReference();
    final TrackingCoverage coverage = controller.trackingCoverage(
      const Duration(hours: 24),
    );

    return ListView(
      key: const Key('today-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: <Widget>[
        Text(
          profile.name,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          '${AppDateTimeUtils.approximateAge(profile.birthDate, localNow)} · '
          '${AppDateTimeUtils.formatDate(controller.nowUtc, profile.timezone)}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        CurrentStatusCard(
          openEvent: controller.openEvent,
          lastCompletedEvent: controller.lastCompletedEvent,
          nowUtc: controller.nowUtc,
          isNightAwakening: nightAwakening,
        ),
        const SizedBox(height: 12),
        _PrimaryActions(
          sleeping: sleeping,
          nightAwakening: nightAwakening,
          busy: controller.isBusy,
          onStart: () => _startSleep(context, controller),
          onFinish: () => _finishSleep(context, controller),
          onResumeNight: () => _resumeNight(context, controller),
          onFinishNight: () => _finishNight(context, controller),
        ),
        if (!sleeping && !nightAwakening) ...<Widget>[
          const SizedBox(height: 12),
          PredictionCard(
            prediction: controller.currentPrediction,
            timezone: profile.timezone,
            nowUtc: controller.nowUtc,
            onDetails: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const PredictionDetailsScreen(),
                ),
              );
            },
          ),
        ],
        if (!sleeping &&
            !nightAwakening &&
            controller.bedtimeEstimate != null) ...<Widget>[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.bedtime_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Inicio nocturno probable',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${AppDateTimeUtils.formatTime(controller.bedtimeEstimate!.windowStartUtc, profile.timezone)} '
                          '– ${AppDateTimeUtils.formatTime(controller.bedtimeEstimate!.windowEndUtc, profile.timezone)}',
                        ),
                      ],
                    ),
                  ),
                ],
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
          showRangeComparison: coverage.level == TrackingCoverageLevel.complete,
          isHighlyVariableAge: underFourMonths,
        ),
        if (controller.recentEvents.isNotEmpty) ...<Widget>[
          const SizedBox(height: 18),
          Text(
            'Últimos registros',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: <Widget>[
                for (
                  int index = 0;
                  index < controller.recentEvents.length;
                  index += 1
                ) ...<Widget>[
                  _RecentEventTile(
                    event: controller.recentEvents[index],
                    timezone: profile.timezone,
                    nowUtc: controller.nowUtc,
                  ),
                  if (index < controller.recentEvents.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
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
                    minTileHeight: 56,
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
    await _runAction(context, () => controller.startSleep(type: selected));
  }

  Future<void> _finishSleep(
    BuildContext context,
    AppController controller,
  ) async {
    await _runAction(context, controller.finishSleep);
  }

  Future<void> _resumeNight(
    BuildContext context,
    AppController controller,
  ) async {
    await _runAction(context, controller.resumeNightSleep);
  }

  Future<void> _finishNight(
    BuildContext context,
    AppController controller,
  ) async {
    await _runAction(context, controller.finishNight);
  }

  Future<void> _runAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({
    required this.sleeping,
    required this.nightAwakening,
    required this.busy,
    required this.onStart,
    required this.onFinish,
    required this.onResumeNight,
    required this.onFinishNight,
  });

  final bool sleeping;
  final bool nightAwakening;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onFinish;
  final VoidCallback onResumeNight;
  final VoidCallback onFinishNight;

  @override
  Widget build(BuildContext context) {
    if (nightAwakening) {
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double scale = MediaQuery.textScalerOf(context).scale(1);
          final bool stack = constraints.maxWidth < 430 || scale >= 1.3;
          final List<Widget> buttons = <Widget>[
            FilledButton.icon(
              key: const Key('resume-night-button'),
              onPressed: busy ? null : onResumeNight,
              icon: const Icon(Icons.bedtime_rounded),
              label: const Text('Volvió a dormir'),
            ),
            OutlinedButton.icon(
              key: const Key('finish-night-button'),
              onPressed: busy ? null : onFinishNight,
              icon: const Icon(Icons.wb_sunny_outlined),
              label: const Text('Terminó la noche'),
            ),
          ];
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                buttons[0],
                const SizedBox(height: 8),
                buttons[1],
              ],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(child: buttons[0]),
              const SizedBox(width: 8),
              Expanded(child: buttons[1]),
            ],
          );
        },
      );
    }
    return Semantics(
      button: true,
      label: sleeping ? 'Finalizar sueño' : 'Iniciar sueño',
      child: FilledButton.icon(
        key: Key(sleeping ? 'finish-sleep-button' : 'start-sleep-button'),
        onPressed: busy
            ? null
            : sleeping
            ? onFinish
            : onStart,
        icon: Icon(sleeping ? Icons.stop_rounded : Icons.play_arrow_rounded),
        label: Text(sleeping ? 'Finalizar sueño' : 'Iniciar sueño'),
      ),
    );
  }
}

class _RecentEventTile extends StatelessWidget {
  const _RecentEventTile({
    required this.event,
    required this.timezone,
    required this.nowUtc,
  });

  final SleepEvent event;
  final String timezone;
  final DateTime nowUtc;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 60,
      leading: Icon(
        event.type == SleepType.nap
            ? Icons.light_mode_outlined
            : Icons.dark_mode_outlined,
      ),
      title: Text(
        AppDateTimeUtils.formatDuration(event.durationAt(nowUtc)),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${event.type.label} · '
        '${AppDateTimeUtils.formatTime(event.startUtc, timezone)}–'
        '${event.endUtc == null ? 'en curso' : AppDateTimeUtils.formatTime(event.endUtc!, timezone)}',
      ),
    );
  }
}
