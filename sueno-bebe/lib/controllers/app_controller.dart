import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../constants/sleep_reference_ranges.dart';
import '../data/baby_repository.dart';
import '../data/sleep_repository.dart';
import '../models/baby_profile.dart';
import '../models/sleep_event.dart';
import '../models/sleep_prediction.dart';
import '../models/sleep_statistics.dart';
import '../models/tracking_coverage.dart';
import '../services/export_service.dart';
import '../services/notification_service.dart';
import '../services/prediction_service.dart';
import '../services/statistics_service.dart';
import '../utils/date_time_utils.dart';

enum AppThemePreference { system, light, dark }

class AppController extends ChangeNotifier {
  AppController({
    BabyRepository? babyRepository,
    SleepRepository? sleepRepository,
    StatisticsService? statisticsService,
    PredictionService? predictionService,
    NotificationService? notificationService,
    ExportService? exportService,
    SharedPreferencesAsync? preferences,
    Uuid? uuid,
    DateTime Function()? nowProvider,
  }) : _babyRepository = babyRepository ?? BabyRepository(),
       _sleepRepository = sleepRepository ?? SleepRepository(),
       _statisticsService = statisticsService ?? const StatisticsService(),
       _predictionService = predictionService ?? const PredictionService(),
       _notificationService = notificationService ?? NotificationService(),
       _exportService = exportService ?? const ExportService(),
       _preferences = preferences ?? SharedPreferencesAsync(),
       _uuid = uuid ?? const Uuid(),
       _nowProvider = nowProvider ?? DateTime.now,
       _clock = (nowProvider ?? DateTime.now)().toUtc();

  static const String _themeKey = 'theme_preference';
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _notificationAdvanceKey = 'notification_advance_minutes';
  static const String _endedNightWakeKey = 'ended_night_wake_utc';

  final BabyRepository _babyRepository;
  final SleepRepository _sleepRepository;
  final StatisticsService _statisticsService;
  final PredictionService _predictionService;
  final NotificationService _notificationService;
  final ExportService _exportService;
  final SharedPreferencesAsync _preferences;
  final Uuid _uuid;
  final DateTime Function() _nowProvider;

  BabyProfile? profile;
  List<SleepEvent> events = <SleepEvent>[];
  List<SleepPrediction> predictions = <SleepPrediction>[];
  SleepPrediction? currentPrediction;
  BedtimeEstimate? bedtimeEstimate;
  SleepStatistics? rolling24Hours;
  SleepStatistics? selectedStatistics;
  Duration statisticsPeriod = const Duration(days: 7);
  AppThemePreference themePreference = AppThemePreference.system;
  bool notificationsEnabled = false;
  int notificationAdvanceMinutes = 15;
  bool isLoading = true;
  bool isBusy = false;
  String? userMessage;
  String? technicalErrorCode;
  DateTime? _endedNightWakeUtc;
  Timer? _ticker;
  DateTime _clock;

  DateTime get nowUtc => _clock;

  SleepEvent? get openEvent {
    for (final SleepEvent event in events) {
      if (event.isOpen) {
        return event;
      }
    }
    return null;
  }

  SleepEvent? get lastCompletedEvent {
    SleepEvent? latest;
    for (final SleepEvent event in events) {
      if (event.endUtc != null &&
          (latest == null || event.endUtc!.isAfter(latest.endUtc!))) {
        latest = event;
      }
    }
    return latest;
  }

  List<SleepEvent> get recentEvents {
    final List<SleepEvent> result = List<SleepEvent>.of(events)
      ..sort((SleepEvent a, SleepEvent b) => b.startUtc.compareTo(a.startUtc));
    return result.take(3).toList(growable: false);
  }

  bool get hasProfile => profile != null;

  ThemeMode get themeMode => switch (themePreference) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };

  tz.Location get location {
    final String identifier =
        profile?.timezone ?? _notificationService.timezoneIdentifier;
    return AppDateTimeUtils.safeLocation(identifier);
  }

  bool get isNightPeriod {
    final int hour = tz.TZDateTime.from(nowUtc, location).hour;
    return hour >= 18 || hour < 6;
  }

  bool get isNightAwakening {
    final SleepEvent? latest = lastCompletedEvent;
    if (!isNightPeriod ||
        openEvent != null ||
        latest == null ||
        latest.type != SleepType.night ||
        latest.endUtc == null) {
      return false;
    }
    if (_endedNightWakeUtc?.isAtSameMomentAs(latest.endUtc!) ?? false) {
      return false;
    }
    final String currentNight = _statisticsService.nightKey(nowUtc, location);
    final String eventNight = _statisticsService.nightKey(
      latest.startUtc,
      location,
    );
    return currentNight == eventNight &&
        nowUtc.difference(latest.endUtc!).inHours <= 8;
  }

  TrackingCoverage trackingCoverage(Duration period) {
    final BabyProfile current = _requireProfile();
    final List<SleepEvent> completed =
        events.where((SleepEvent event) => event.endUtc != null).toList()..sort(
          (SleepEvent a, SleepEvent b) => a.startUtc.compareTo(b.startUtc),
        );
    final DateTime firstRecordUtc = completed.isEmpty
        ? current.createdAtUtc
        : completed.first.startUtc;
    final DateTime trackingStartUtc =
        firstRecordUtc.isAfter(current.createdAtUtc)
        ? firstRecordUtc
        : current.createdAtUtc;
    final Duration tracked = nowUtc.isAfter(trackingStartUtc)
        ? nowUtc.difference(trackingStartUtc)
        : Duration.zero;
    final TrackingCoverageLevel level = tracked < period
        ? TrackingCoverageLevel.incomplete
        : completed.length < 3
        ? TrackingCoverageLevel.completeFewRecords
        : TrackingCoverageLevel.complete;
    return TrackingCoverage(
      level: level,
      trackedDuration: tracked,
      requestedPeriod: period,
      completedEventCount: completed.length,
      trackingStartUtc: trackingStartUtc,
    );
  }

  Future<void> initialize() async {
    isLoading = true;
    notifyListeners();
    try {
      tz_data.initializeTimeZones();
      await _loadPreferences();
      try {
        await _notificationService.initialize();
      } on Object catch (error, stackTrace) {
        _recordError('NOTIFICATION_INIT', error, stackTrace);
      }
      profile = await _babyRepository.getActiveProfile();
      await _reloadData();
      _startTicker();
    } on Object catch (error, stackTrace) {
      _recordError('INIT', error, stackTrace);
      userMessage = 'No fue posible abrir los datos locales de la aplicación.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadPreferences() async {
    final String value =
        await _preferences.getString(_themeKey) ??
        AppThemePreference.system.name;
    themePreference = AppThemePreference.values.firstWhere(
      (AppThemePreference item) => item.name == value,
      orElse: () => AppThemePreference.system,
    );
    notificationsEnabled =
        await _preferences.getBool(_notificationsEnabledKey) ?? false;
    notificationAdvanceMinutes =
        await _preferences.getInt(_notificationAdvanceKey) ?? 15;
    final int? endedWake = await _preferences.getInt(_endedNightWakeKey);
    _endedNightWakeUtc = endedWake == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(endedWake, isUtc: true);
  }

  Future<void> createProfile({
    required String name,
    required DateTime birthDate,
    DateTime? expectedDueDate,
    String? notes,
    required AppThemePreference theme,
  }) async {
    final String cleanedName = name.trim();
    if (cleanedName.isEmpty) {
      throw const FormatException('Ingresa un nombre o apodo.');
    }
    _validateBirthDate(birthDate);
    final DateTime now = _nowProvider().toUtc();
    final BabyProfile created = BabyProfile(
      id: _uuid.v4(),
      name: cleanedName,
      birthDate: birthDate,
      expectedDueDate: expectedDueDate,
      notes: _cleanOptional(notes),
      timezone: _notificationService.timezoneIdentifier,
      createdAtUtc: now,
      modifiedAtUtc: now,
    );
    await _runBusy(() async {
      await _babyRepository.save(created);
      profile = created;
      await setThemePreference(theme);
      await _reloadData();
    });
  }

  Future<void> updateProfile({
    required String name,
    required DateTime birthDate,
    DateTime? expectedDueDate,
    String? notes,
  }) async {
    final BabyProfile current = _requireProfile();
    final String cleanedName = name.trim();
    if (cleanedName.isEmpty) {
      throw const FormatException('Ingresa un nombre o apodo.');
    }
    _validateBirthDate(birthDate);
    final BabyProfile updated = current.copyWith(
      name: cleanedName,
      birthDate: birthDate,
      expectedDueDate: expectedDueDate,
      clearExpectedDueDate: expectedDueDate == null,
      notes: _cleanOptional(notes),
      clearNotes: _cleanOptional(notes) == null,
      modifiedAtUtc: _nowProvider().toUtc(),
    );
    await _runBusy(() async {
      await _babyRepository.save(updated);
      profile = updated;
      await _recalculate();
    });
  }

  SleepType suggestedSleepType() =>
      isNightPeriod ? SleepType.night : SleepType.nap;

  Future<void> startSleep({SleepType? type}) async {
    final SleepType selected = type ?? suggestedSleepType();
    final bool evaluatePrediction =
        !(selected == SleepType.night && isNightAwakening);
    await _startSleepInternal(
      type: selected,
      evaluatePrediction: evaluatePrediction,
    );
  }

  Future<void> resumeNightSleep() async {
    if (!isNightAwakening) {
      throw StateError('No existe un despertar nocturno pendiente.');
    }
    await _startSleepInternal(type: SleepType.night, evaluatePrediction: false);
  }

  Future<void> finishNight() async {
    final SleepEvent? latest = lastCompletedEvent;
    if (latest?.endUtc == null || !isNightAwakening) {
      return;
    }
    _endedNightWakeUtc = latest!.endUtc!.toUtc();
    await _preferences.setInt(
      _endedNightWakeKey,
      _endedNightWakeUtc!.millisecondsSinceEpoch,
    );
    await _recalculatePrediction();
    notifyListeners();
  }

  Future<void> _startSleepInternal({
    required SleepType type,
    required bool evaluatePrediction,
  }) async {
    final BabyProfile current = _requireProfile();
    if (openEvent != null) {
      throw StateError('Ya existe un sueño en curso.');
    }
    final DateTime now = _nowProvider().toUtc();
    final SleepEvent event = SleepEvent(
      id: _uuid.v4(),
      babyId: current.id,
      startUtc: now,
      type: type,
      accuracy: SleepAccuracy.exact,
      origin: SleepOrigin.timer,
      timezone: current.timezone,
      createdAtUtc: now,
      modifiedAtUtc: now,
    );
    await _runBusy(() async {
      if (type == SleepType.night) {
        await _clearEndedNightWake();
      }
      await _sleepRepository.saveEvent(
        event,
        nowUtc: now,
        evaluatePrediction: evaluatePrediction,
      );
      await _cancelPredictionNotification();
      await _reloadData();
    });
  }

  Future<void> finishSleep() async {
    final SleepEvent current =
        openEvent ?? (throw StateError('No existe un sueño en curso.'));
    final DateTime now = _nowProvider().toUtc();
    final SleepEvent completed = current.copyWith(
      endUtc: now,
      modifiedAtUtc: now,
    );
    await _runBusy(() async {
      await _sleepRepository.saveEvent(completed, nowUtc: now);
      await _reloadData();
    });
  }

  Future<void> saveManualEvent(SleepEvent event) async {
    final DateTime now = _nowProvider().toUtc();
    await _runBusy(() async {
      final bool isNew = !events.any((SleepEvent item) => item.id == event.id);
      await _sleepRepository.saveEvent(
        event.copyWith(modifiedAtUtc: now),
        nowUtc: now,
        evaluatePrediction: isNew,
      );
      await _reloadData();
    });
  }

  Future<void> deleteEvent(String id) async {
    await _runBusy(() async {
      await _sleepRepository.deleteEvent(id);
      await _reloadData();
    });
  }

  Future<void> setStatisticsPeriod(Duration value) async {
    statisticsPeriod = value;
    _calculateStatistics();
    notifyListeners();
  }

  Future<void> setThemePreference(AppThemePreference value) async {
    themePreference = value;
    await _preferences.setString(_themeKey, value.name);
    notifyListeners();
  }

  Future<bool> enableNotificationsWithPermission() async {
    final bool granted = await _notificationService.requestPermission();
    notificationsEnabled = granted;
    await _preferences.setBool(_notificationsEnabledKey, granted);
    if (granted) {
      await _scheduleCurrentPrediction(throwOnError: true);
    }
    notifyListeners();
    return granted;
  }

  Future<void> setNotificationsEnabled(bool value) async {
    notificationsEnabled = value;
    await _preferences.setBool(_notificationsEnabledKey, value);
    if (value) {
      await _scheduleCurrentPrediction(throwOnError: true);
    } else {
      await _cancelPredictionNotification(throwOnError: true);
    }
    notifyListeners();
  }

  Future<void> setNotificationAdvance(int minutes) async {
    if (!<int>[0, 10, 15, 30].contains(minutes)) {
      throw ArgumentError.value(minutes, 'minutes');
    }
    notificationAdvanceMinutes = minutes;
    await _preferences.setInt(_notificationAdvanceKey, minutes);
    await _scheduleCurrentPrediction(throwOnError: true);
    notifyListeners();
  }

  Future<File> exportData() async {
    final List<BabyProfile> profiles = await _babyRepository.getAllProfiles();
    return _exportService.createCsv(
      profiles: profiles,
      events: events,
      predictions: predictions,
      generatedAtUtc: _nowProvider().toUtc(),
    );
  }

  Future<void> shareExport(File file) => _exportService.shareCsv(file);

  Future<void> deleteAllData() async {
    await _runBusy(() async {
      try {
        await _notificationService.cancelAll();
      } on Object catch (error, stackTrace) {
        _recordError('NOTIFICATION_CANCEL_ALL', error, stackTrace);
      }
      await _sleepRepository.deleteAll();
      await _babyRepository.deleteAll();
      await _preferences.clear(
        allowList: <String>{
          _themeKey,
          _notificationsEnabledKey,
          _notificationAdvanceKey,
          _endedNightWakeKey,
        },
      );
      profile = null;
      events = <SleepEvent>[];
      predictions = <SleepPrediction>[];
      currentPrediction = null;
      bedtimeEstimate = null;
      rolling24Hours = null;
      selectedStatistics = null;
      notificationsEnabled = false;
      notificationAdvanceMinutes = 15;
      themePreference = AppThemePreference.system;
      _endedNightWakeUtc = null;
    });
  }

  String sleepRangeStatus() {
    final BabyProfile? current = profile;
    final SleepStatistics? stats = rolling24Hours;
    if (current == null || stats == null) {
      return 'Sin datos suficientes';
    }
    final TrackingCoverage coverage = trackingCoverage(
      const Duration(hours: 24),
    );
    if (coverage.level == TrackingCoverageLevel.incomplete) {
      return coverage.message;
    }
    if (coverage.level == TrackingCoverageLevel.completeFewRecords) {
      return coverage.message;
    }
    final tz.TZDateTime localNow = tz.TZDateTime.from(nowUtc, location);
    final int months = AppDateTimeUtils.ageInMonths(
      current.birthDate,
      localNow,
    );
    final SleepAmountReference reference = sleepAmountReferenceForAgeMonths(
      months,
    );
    final double hours = stats.totalMinutes / 60;
    if (hours < reference.minimumHours) {
      return 'Bajo el rango general durante este período';
    }
    if (hours > reference.maximumHours) {
      return 'Sobre el rango general durante este período';
    }
    return 'Dentro del rango general';
  }

  SleepAmountReference? currentSleepAmountReference() {
    final BabyProfile? current = profile;
    if (current == null) {
      return null;
    }
    final tz.TZDateTime localNow = tz.TZDateTime.from(nowUtc, location);
    return sleepAmountReferenceForAgeMonths(
      AppDateTimeUtils.ageInMonths(current.birthDate, localNow),
    );
  }

  Future<void> _reloadData() async {
    final BabyProfile? current = profile;
    if (current == null) {
      events = <SleepEvent>[];
      predictions = <SleepPrediction>[];
      currentPrediction = null;
      rolling24Hours = null;
      selectedStatistics = null;
      return;
    }
    events = await _sleepRepository.getEvents(current.id);
    predictions = await _sleepRepository.getPredictions(current.id);
    await _recalculate();
  }

  Future<void> _recalculate() async {
    _clock = _nowProvider().toUtc();
    _calculateStatistics();
    await _recalculatePrediction();
    notifyListeners();
  }

  void _calculateStatistics() {
    final BabyProfile? current = profile;
    if (current == null) {
      rolling24Hours = null;
      selectedStatistics = null;
      return;
    }
    rolling24Hours = _statisticsService.calculate(
      events: events,
      predictions: predictions,
      period: const Duration(hours: 24),
      nowUtc: nowUtc,
      location: location,
    );
    selectedStatistics = _statisticsService.calculate(
      events: events,
      predictions: predictions,
      period: statisticsPeriod,
      nowUtc: nowUtc,
      location: location,
    );
  }

  Future<void> _recalculatePrediction() async {
    final BabyProfile? current = profile;
    if (current == null || openEvent != null || isNightAwakening) {
      currentPrediction = null;
      bedtimeEstimate = null;
      await _cancelPredictionNotification();
      return;
    }
    final bool hasCompleted = events.any(
      (SleepEvent event) => event.endUtc != null,
    );
    if (!hasCompleted) {
      currentPrediction = null;
      bedtimeEstimate = null;
      await _cancelPredictionNotification();
      return;
    }
    try {
      final SleepPrediction prediction = _predictionService.createPrediction(
        id: _uuid.v4(),
        profile: current,
        events: events,
        nowUtc: nowUtc,
        location: location,
      );
      final SleepPrediction? previous = await _sleepRepository
          .getLatestPrediction(current.id);
      final bool sameWake = previous?.lastWakeUtc == prediction.lastWakeUtc;
      currentPrediction = sameWake ? previous : prediction;
      if (!sameWake) {
        await _sleepRepository.savePrediction(prediction);
        predictions = await _sleepRepository.getPredictions(current.id);
      }
      bedtimeEstimate = _predictionService.estimateBedtime(
        profile: current,
        events: events,
        nowUtc: nowUtc,
        location: location,
      );
      await _scheduleCurrentPrediction();
    } on StateError {
      currentPrediction = null;
      bedtimeEstimate = null;
    }
  }

  Future<void> _scheduleCurrentPrediction({bool throwOnError = false}) async {
    final SleepPrediction? prediction = currentPrediction;
    final BabyProfile? current = profile;
    if (!notificationsEnabled || prediction == null || current == null) {
      await _cancelPredictionNotification(throwOnError: throwOnError);
      return;
    }
    try {
      await _notificationService.schedulePrediction(
        prediction: prediction,
        babyName: current.name,
        advanceMinutes: notificationAdvanceMinutes,
        nowUtc: nowUtc,
      );
    } on Object catch (error, stackTrace) {
      _recordError('NOTIFICATION_SCHEDULE', error, stackTrace);
      userMessage = 'No fue posible programar el recordatorio local.';
      if (throwOnError) {
        rethrow;
      }
    }
  }

  Future<void> _cancelPredictionNotification({
    bool throwOnError = false,
  }) async {
    try {
      await _notificationService.cancelPrediction();
    } on Object catch (error, stackTrace) {
      _recordError('NOTIFICATION_CANCEL', error, stackTrace);
      userMessage = 'No fue posible cancelar el recordatorio local anterior.';
      if (throwOnError) {
        rethrow;
      }
    }
  }

  Future<void> _clearEndedNightWake() async {
    _endedNightWakeUtc = null;
    await _preferences.remove(_endedNightWakeKey);
  }

  Future<void> _runBusy(Future<void> Function() operation) async {
    isBusy = true;
    userMessage = null;
    notifyListeners();
    try {
      await operation();
    } on Object catch (error, stackTrace) {
      _recordError('ACTION', error, stackTrace);
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  BabyProfile _requireProfile() =>
      profile ?? (throw StateError('Primero crea el perfil del bebé.'));

  void _validateBirthDate(DateTime birthDate) {
    final DateTime now = _nowProvider().toUtc();
    final tz.TZDateTime todayLocal = tz.TZDateTime.from(now, location);
    final DateTime selected = DateTime(
      birthDate.year,
      birthDate.month,
      birthDate.day,
    );
    final DateTime today = DateTime(
      todayLocal.year,
      todayLocal.month,
      todayLocal.day,
    );
    if (selected.isAfter(today)) {
      throw const FormatException(
        'La fecha de nacimiento no puede estar en el futuro.',
      );
    }
  }

  String? _cleanOptional(String? value) {
    final String cleaned = value?.trim() ?? '';
    return cleaned.isEmpty ? null : cleaned;
  }

  void clearUserMessage() {
    userMessage = null;
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      _clock = _nowProvider().toUtc();
      if (openEvent != null) {
        _calculateStatistics();
      }
      notifyListeners();
    });
  }

  void _recordError(String code, Object error, StackTrace _) {
    technicalErrorCode = code;
    assert(() {
      debugPrint('Sueño Bebé [$code]: ${error.runtimeType}');
      return true;
    }());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
