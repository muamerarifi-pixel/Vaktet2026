import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../logic/cities.dart';
import '../logic/day.dart';
import '../logic/prayer.dart';

/// The six daily prayer/sky times users can individually toggle for Android notifications.
enum NotifyPrayer {
  imsak(PrayerKey.imsak, 'Imsaku', true),
  sunrise(PrayerKey.sunrise, 'Lindja e diellit', false),
  dreka(PrayerKey.dreka, 'Dreka', true),
  asr(PrayerKey.asr, 'Ikindia', true),
  maghrib(PrayerKey.maghrib, 'Akshami', true),
  isha(PrayerKey.isha, 'Jacia', true);

  const NotifyPrayer(this.key, this.label, this.byDefault);

  final PrayerKey key;
  final String label;
  final bool byDefault;

  String get prefKey => 'notif_p_$name';
}

/// Bridge to Android's native AlarmManager & NotificationManager (`com.vaktet.vaktet/notifications`).
/// No-ops safely on Windows, Web, and in widget tests.
class NotificationService {
  static const _channel = MethodChannel('com.vaktet.vaktet/notifications');

  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> hasPermission() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> requestPermission() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> cancelAll() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('cancelAll');
    } on MissingPluginException {
      // Ignore in tests or unsupported platforms
    } on PlatformException {
      // Ignore
    }
  }

  static Future<void> showTest(City city) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('showTest', {
        'title': 'Vaktet — Njoftimet aktive',
        'body': 'Do të njoftoheni në kohë për vaktet e namazit (${city.name}).',
      });
    } on MissingPluginException {
      // Ignore
    } on PlatformException {
      // Ignore
    }
  }

  static Future<void> syncWidgetSchedule({
    required City city,
    required int nowUtcMs,
    int days = 30,
  }) async {
    if (!isSupported) return;
    final items = buildWidgetSchedule(city: city, nowUtcMs: nowUtcMs, days: days);
    try {
      await _channel.invokeMethod<void>('updateWidget', {'items': items});
    } on MissingPluginException {
      // Ignore in tests
    } on PlatformException {
      // Ignore
    }
  }

  /// Builds the next [days] days of countdown targets (excluding Sabahu & Hyrja e drekës) for the lock/home widget.
  static List<Map<String, Object>> buildWidgetSchedule({
    required City city,
    required int nowUtcMs,
    int days = 30,
  }) {
    final startDay = kosovoToday(nowUtcMs);
    final items = <Map<String, Object>>[];
    const widgetKeys = {
      PrayerKey.imsak,
      PrayerKey.sunrise,
      PrayerKey.dreka,
      PrayerKey.asr,
      PrayerKey.maghrib,
      PrayerKey.isha,
    };
    for (var d = 0; d < days; d++) {
      final rows = dayRows(startDay.addDays(d), city);
      for (final row in rows) {
        if (!widgetKeys.contains(row.key)) continue;
        if (row.instant <= nowUtcMs) continue;
        items.add({'name': row.name, 'instantMs': row.instant});
      }
    }
    return items;
  }

  /// Schedules the next [days] days of enabled prayer notifications for [city].
  static Future<void> scheduleUpcoming({
    required City city,
    required Map<NotifyPrayer, bool> enabled,
    required int beforeMin,
    required int nowUtcMs,
    int days = 14,
  }) async {
    if (!isSupported) return;
    final items = buildSchedule(
      city: city,
      enabled: enabled,
      beforeMin: beforeMin,
      nowUtcMs: nowUtcMs,
      days: days,
    );
    try {
      await _channel.invokeMethod<void>('schedule', {'items': items});
    } on MissingPluginException {
      // Ignore in tests
    } on PlatformException {
      // Ignore
    }
  }

  /// Pure helper (also unit-testable) that builds the exact upcoming alarm list.
  static List<Map<String, Object>> buildSchedule({
    required City city,
    required Map<NotifyPrayer, bool> enabled,
    required int beforeMin,
    required int nowUtcMs,
    int days = 14,
  }) {
    final startDay = kosovoToday(nowUtcMs);
    final items = <Map<String, Object>>[];
    final offsetMs = beforeMin * msPerMinute;

    for (var d = 0; d < days; d++) {
      final day = startDay.addDays(d);
      final rows = dayRows(day, city);
      for (final p in NotifyPrayer.values) {
        if (!(enabled[p] ?? p.byDefault)) continue;
        final row = rows.firstWhere((r) => r.key == p.key);
        final triggerAt = row.instant - offsetMs;
        if (triggerAt <= nowUtcMs) continue;

        final hhmm = '${(row.local ~/ 60).toString().padLeft(2, '0')}:${(row.local % 60).toString().padLeft(2, '0')}';
        final (title, body) = _copy(p, row.name, hhmm, city.name, beforeMin);
        // Deterministic unique ID per day & prayer (safe 32-bit int)
        final id = (day.epochDay % 100000) * 10 + p.index + 1000;
        items.add({
          'id': id,
          'triggerAtMs': triggerAt,
          'title': title,
          'body': body,
        });
      }
    }
    return items;
  }

  static (String, String) _copy(NotifyPrayer p, String rowName, String hhmm, String cityName, int beforeMin) {
    if (beforeMin > 0) {
      return (
        '$rowName pas $beforeMin min ($hhmm)',
        p == NotifyPrayer.sunrise
            ? 'Dielli lind në $hhmm • $cityName'
            : 'Përgatitu për vaktin e namazit • $cityName',
      );
    }
    if (p == NotifyPrayer.sunrise) {
      return ('Lindja e diellit — $hhmm', 'Dielli po lind • $cityName');
    }
    return ('$rowName — $hhmm', 'Ka hyrë koha e namazit • $cityName');
  }
}
