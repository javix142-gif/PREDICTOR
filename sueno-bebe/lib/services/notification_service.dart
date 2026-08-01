import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/sleep_prediction.dart';

class NotificationServiceException implements Exception {
  const NotificationServiceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const int predictionNotificationId = 41001;
  static const String channelId = 'sleep_window_reminders';
  static const String channelName = 'Ventanas de sueño';
  static const String channelDescription =
      'Recordatorios orientativos de próximas ventanas de sueño.';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  String _timezoneIdentifier = 'UTC';

  String get timezoneIdentifier => _timezoneIdentifier;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    try {
      tz_data.initializeTimeZones();
      try {
        final TimezoneInfo timezoneInfo =
            await FlutterTimezone.getLocalTimezone();
        _timezoneIdentifier = timezoneInfo.identifier;
        tz.setLocalLocation(tz.getLocation(_timezoneIdentifier));
      } on Object {
        _timezoneIdentifier = 'UTC';
        tz.setLocalLocation(tz.UTC);
      }
      const InitializationSettings settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings: settings);
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await android?.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
            importance: Importance.defaultImportance,
          ),
        );
      }
      _initialized = true;
    } on Object catch (error) {
      throw NotificationServiceException(
        'No fue posible inicializar las notificaciones locales.',
        error,
      );
    }
  }

  Future<bool> requestPermission() async {
    await initialize();
    try {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await android?.requestNotificationsPermission() ?? true;
      }
      if (Platform.isIOS) {
        final IOSFlutterLocalNotificationsPlugin? ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await ios?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      return true;
    } on Object catch (error) {
      throw NotificationServiceException(
        'No fue posible solicitar el permiso de notificaciones.',
        error,
      );
    }
  }

  Future<bool> areNotificationsEnabled() async {
    await initialize();
    if (!Platform.isAndroid) {
      return true;
    }
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.areNotificationsEnabled() ?? true;
  }

  Future<void> schedulePrediction({
    required SleepPrediction prediction,
    required String babyName,
    required int advanceMinutes,
    required DateTime nowUtc,
  }) async {
    await initialize();
    await cancelPrediction();
    final DateTime scheduledUtc = prediction.windowStartUtc
        .subtract(Duration(minutes: advanceMinutes))
        .toUtc();
    if (!scheduledUtc.isAfter(nowUtc.toUtc())) {
      return;
    }
    try {
      final tz.TZDateTime scheduled = tz.TZDateTime.from(
        scheduledUtc,
        tz.local,
      );
      await _plugin.zonedSchedule(
        id: predictionNotificationId,
        title: 'Ventana orientativa de sueño',
        body:
            'Se aproxima la ventana de sueño de $babyName. '
            'Observa sus señales de cansancio.',
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: prediction.id,
      );
    } on Object catch (error) {
      throw NotificationServiceException(
        'No fue posible programar el recordatorio.',
        error,
      );
    }
  }

  Future<void> cancelPrediction() async {
    await initialize();
    try {
      await _plugin.cancel(id: predictionNotificationId);
    } on Object catch (error) {
      throw NotificationServiceException(
        'No fue posible cancelar el recordatorio anterior.',
        error,
      );
    }
  }

  Future<void> cancelAll() async {
    await initialize();
    try {
      await _plugin.cancelAll();
    } on Object catch (error) {
      throw NotificationServiceException(
        'No fue posible cancelar las notificaciones.',
        error,
      );
    }
  }
}
