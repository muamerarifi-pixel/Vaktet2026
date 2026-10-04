/// Calendar helpers: a time-zone-free calendar day and Kosovo's UTC offset.
library;

const int msPerMinute = 60000;
const int msPerHour = 3600000;
const int msPerDay = 86400000;

/// A calendar day (year, month 1–12, day), like the web app's `{y, m, d}`.
class Day {
  const Day(this.y, this.m, this.d);

  factory Day.fromUtcMs(int ms) {
    final t = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    return Day(t.year, t.month, t.day);
  }

  final int y;
  final int m;
  final int d;

  /// Midnight UTC of this day, in epoch milliseconds.
  int get utcMs => DateTime.utc(y, m, d).millisecondsSinceEpoch;

  /// Days since 1970-01-01.
  int get epochDay => utcMs ~/ msPerDay;

  Day addDays(int n) => Day.fromUtcMs(utcMs + n * msPerDay);

  /// 0 = Sunday … 6 = Saturday (the same as JavaScript's `getUTCDay`).
  int get weekday => DateTime.utc(y, m, d).weekday % 7;

  static int daysInMonth(int y, int m) => DateTime.utc(y, m + 1, 0).day;

  @override
  bool operator ==(Object other) => other is Day && other.y == y && other.m == m && other.d == d;

  @override
  int get hashCode => Object.hash(y, m, d);

  @override
  String toString() => '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
}

// ---------- Kosovo time (Europe/Belgrade) ----------
//
// Kosovo follows the EU rule: summer time (UTC+2) from 01:00 UTC on the last Sunday of March
// until 01:00 UTC on the last Sunday of October, standard time (UTC+1) otherwise. The app works
// offline, so the rule is built in rather than read from a time-zone database.

int _lastSundayAt0100Utc(int year, int month) {
  final last = DateTime.utc(year, month + 1, 0);
  final dayOfMonth = last.day - (last.weekday % 7);
  return DateTime.utc(year, month, dayOfMonth, 1).millisecondsSinceEpoch;
}

/// Kosovo's offset from UTC, in minutes, at an instant.
int kosovoOffsetAt(int utcMs) {
  final year = DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true).year;
  final summer = utcMs >= _lastSundayAt0100Utc(year, 3) && utcMs < _lastSundayAt0100Utc(year, 10);
  return summer ? 120 : 60;
}

/// Kosovo's offset from UTC, in minutes, on a given day (read at 10:00 UTC, as the web app does).
int kosovoOffsetForDay(Day day) => kosovoOffsetAt(day.utcMs + 10 * msPerHour);

/// The calendar date in Kosovo at an instant.
Day kosovoToday(int nowUtcMs) => Day.fromUtcMs(nowUtcMs + kosovoOffsetAt(nowUtcMs) * msPerMinute);
