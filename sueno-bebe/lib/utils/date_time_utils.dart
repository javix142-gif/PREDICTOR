import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

class AppDateTimeUtils {
  const AppDateTimeUtils._();

  static tz.Location safeLocation(String identifier) {
    if (identifier == 'UTC' || identifier == 'Etc/UTC') {
      return tz.UTC;
    }
    try {
      return tz.getLocation(identifier);
    } on Object {
      return tz.UTC;
    }
  }

  static tz.TZDateTime toLocal(DateTime utc, String timezone) {
    return tz.TZDateTime.from(utc.toUtc(), safeLocation(timezone));
  }

  static DateTime localWallClockToUtc(DateTime localValue, String timezone) {
    final tz.Location location = safeLocation(timezone);
    return tz.TZDateTime(
      location,
      localValue.year,
      localValue.month,
      localValue.day,
      localValue.hour,
      localValue.minute,
      localValue.second,
    ).toUtc();
  }

  static String formatTime(DateTime utc, String timezone) {
    return DateFormat.Hm('es').format(toLocal(utc, timezone));
  }

  static String formatDate(DateTime utc, String timezone) {
    return DateFormat('EEEE d MMMM', 'es').format(toLocal(utc, timezone));
  }

  static String formatShortDate(DateTime utc, String timezone) {
    return DateFormat('dd/MM/yyyy', 'es').format(toLocal(utc, timezone));
  }

  static String formatDuration(Duration duration) {
    final int minutes = duration.inMinutes.abs();
    final int hours = minutes ~/ 60;
    final int remainder = minutes % 60;
    if (hours == 0) {
      return '$remainder min';
    }
    if (remainder == 0) {
      return '$hours h';
    }
    return '$hours h $remainder min';
  }

  static String formatMinutes(double? minutes) {
    if (minutes == null) {
      return 'Sin datos suficientes';
    }
    return formatDuration(Duration(minutes: minutes.round()));
  }

  static int ageInDays(DateTime birthDate, DateTime localNow) {
    final DateTime birth = DateTime(
      birthDate.year,
      birthDate.month,
      birthDate.day,
    );
    final DateTime today = DateTime(
      localNow.year,
      localNow.month,
      localNow.day,
    );
    return today.difference(birth).inDays.clamp(0, 100000).toInt();
  }

  static int ageInMonths(DateTime birthDate, DateTime localNow) {
    int months =
        (localNow.year - birthDate.year) * 12 +
        localNow.month -
        birthDate.month;
    if (localNow.day < birthDate.day) {
      months -= 1;
    }
    return months.clamp(0, 1200).toInt();
  }

  static String approximateAge(DateTime birthDate, DateTime localNow) {
    final int days = ageInDays(birthDate, localNow);
    if (days < 14) {
      return '$days días';
    }
    if (days < 84) {
      return '${(days / 7).floor()} semanas';
    }
    final int months = ageInMonths(birthDate, localNow);
    if (months < 24) {
      return '$months ${months == 1 ? 'mes' : 'meses'}';
    }
    final int years = months ~/ 12;
    final int remainder = months % 12;
    return remainder == 0
        ? '$years ${years == 1 ? 'año' : 'años'}'
        : '$years a $remainder m';
  }
}
