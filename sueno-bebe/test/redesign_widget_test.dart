import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sueno_bebe/controllers/app_controller.dart';
import 'package:sueno_bebe/models/baby_profile.dart';
import 'package:sueno_bebe/models/sleep_event.dart';
import 'package:sueno_bebe/models/sleep_statistics.dart';
import 'package:sueno_bebe/models/tracking_coverage.dart';
import 'package:sueno_bebe/screens/home_screen.dart';
import 'package:sueno_bebe/screens/sleep_event_form_screen.dart';
import 'package:sueno_bebe/screens/statistics_screen.dart';
import 'package:timezone/data/latest.dart' as tz_data;

BabyProfile baby(DateTime now) => BabyProfile(
  id: 'baby-1',
  name: 'Luna',
  birthDate: DateTime(2026, 5, 1),
  timezone: 'UTC',
  createdAtUtc: now.subtract(const Duration(days: 3)),
  modifiedAtUtc: now,
);

SleepEvent night(DateTime start, DateTime end) => SleepEvent(
  id: 'night-1',
  babyId: 'baby-1',
  startUtc: start,
  endUtc: end,
  type: SleepType.night,
  accuracy: SleepAccuracy.exact,
  origin: SleepOrigin.timer,
  timezone: 'UTC',
  createdAtUtc: start,
  modifiedAtUtc: end,
);

Widget withController(
  AppController controller,
  Widget child, {
  double scale = 1,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: ChangeNotifierProvider<AppController>.value(
        value: controller,
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  setUpAll(tz_data.initializeTimeZones);

  testWidgets('Hoy funciona con texto 1.5 y muestra despertar nocturno', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.utc(2026, 8, 1, 2);
    final AppController controller = AppController(nowProvider: () => now)
      ..profile = baby(now)
      ..events = <SleepEvent>[night(DateTime.utc(2026, 7, 31, 22), now)];

    await tester.pumpWidget(
      withController(controller, const TodayContent(), scale: 1.5),
    );

    expect(find.text('Despertar nocturno'), findsOneWidget);
    expect(find.byKey(const Key('resume-night-button')), findsOneWidget);
    expect(find.byKey(const Key('finish-night-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navegación principal conserva las cuatro secciones', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.utc(2026, 8, 1, 12);
    final AppController controller = AppController(nowProvider: () => now)
      ..profile = baby(now);

    await tester.pumpWidget(withController(controller, const HomeScreen()));

    expect(find.text('Hoy'), findsWidgets);
    expect(find.text('Historial'), findsOneWidget);
    expect(find.text('Estadísticas'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
  });

  testWidgets('Estadísticas usa secciones y una columna con texto 1.5', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.utc(2026, 8, 1, 12);
    final SleepStatistics statistics = SleepStatistics(
      periodStartUtc: now.subtract(const Duration(days: 7)),
      periodEndUtc: now,
      totalMinutes: 600,
      dayMinutes: 120,
      nightMinutes: 480,
      napCount: 2,
      nightCount: 1,
      daysWithDataCount: 1,
      averageNapMinutes: 60,
      medianNapMinutes: 60,
      shortestNapMinutes: 50,
      longestNapMinutes: 70,
      longestContinuousSleepMinutes: 480,
      evaluablePredictionCount: 0,
      dailyTotals: <DailySleepTotal>[
        DailySleepTotal(
          localDate: DateTime(2026, 8, 1),
          totalMinutes: 600,
          dayMinutes: 120,
          nightMinutes: 480,
          hasData: true,
        ),
      ],
      napDurationsMinutes: const <double>[50, 70],
      awakeWindowsMinutes: const <double>[],
    );
    final TrackingCoverage coverage = TrackingCoverage(
      level: TrackingCoverageLevel.complete,
      trackedDuration: const Duration(days: 7),
      requestedPeriod: const Duration(days: 7),
      completedEventCount: 3,
      trackingStartUtc: now.subtract(const Duration(days: 7)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: StatisticsSections(
                statistics: statistics,
                coverage: coverage,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Resumen'), findsOneWidget);
    expect(find.text('Siestas'), findsOneWidget);
    expect(find.text('Sueño nocturno'), findsOneWidget);
    expect(find.text('Calidad de datos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gráfico diario muestra ausencia cuando no hay datos', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 240,
          child: DailySleepChart(
            data: <DailySleepTotal>[
              DailySleepTotal(
                localDate: DateTime(2026, 8, 1),
                totalMinutes: 0,
                dayMinutes: 0,
                nightMinutes: 0,
                hasData: false,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('daily-chart-no-data')), findsOneWidget);
  });

  testWidgets('formulario rápido calcula diez minutos', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.utc(2026, 8, 1, 12);
    final AppController controller = AppController(nowProvider: () => now)
      ..profile = baby(now);

    await tester.pumpWidget(
      withController(controller, const SleepEventFormScreen()),
    );
    await tester.tap(find.byKey(const Key('quick-10')));
    await tester.pump();

    expect(find.byKey(const Key('duration-preview')), findsOneWidget);
    expect(find.textContaining('10'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
