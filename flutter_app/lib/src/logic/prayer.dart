/// Prayer times and everything derived from them: the rows of a day, the forbidden times,
/// the sky phase, the sun/moon position, the "next prayer" card and the Sabah alarm suggestion.
///
/// Times come from the BIK Takvim, stored in standard time (UTC+1); summer time is added here.
library;

import 'dart:math' as math;

import '../data/vaktet_base.dart';
import 'cities.dart';
import 'day.dart';
import 'format.dart';

enum PrayerKey { imsak, sabah, sunrise, dhuhr, dreka, asr, maghrib, isha }

class DayTime {
  const DayTime(this.local, this.instant);

  /// Minutes after local midnight.
  final int local;

  /// Epoch milliseconds.
  final int instant;
}

class PrayerRow {
  const PrayerRow(this.name, this.key, this.local, this.instant);

  final String name;
  final PrayerKey key;

  /// Minutes after local midnight.
  final int local;

  /// Epoch milliseconds.
  final int instant;
}

/// Index into the base table. The Takvim repeats every year by calendar date; 29 Feb uses 28 Feb.
int baseIndex(Day day) {
  final d = day.m == 2 && day.d == 29 ? 28 : day.d;
  return DateTime.utc(2026, day.m, d).difference(DateTime.utc(2026, 1, 1)).inDays;
}

/// The seven Takvim times of a day: imsak, sabah, sunrise, dhuhr, asr, maghrib, isha.
List<DayTime> dayTimes(Day day, City city) {
  final idx = baseIndex(day) * 7;
  final off = kosovoOffsetForDay(day);
  final midnightUtc = day.utcMs;
  return List<DayTime>.generate(7, (i) {
    final std = vaktetBase[idx + i] + city.off; // minutes after midnight, UTC+1
    return DayTime(std + (off - 60), midnightUtc + (std - 60) * msPerMinute);
  });
}

final Map<String, List<PrayerRow>> _rowsCache = {};

/// Rows for one day, in time order (the countdown targets).
/// Obligatory times follow the BIK Takvim, with Dreka/Xhumaja on the full hour as on takvimi.net.
List<PrayerRow> dayRows(Day day, City city) {
  final cacheKey = '$day:${city.id}';
  final hit = _rowsCache[cacheKey];
  if (hit != null) return hit;
  final t = dayTimes(day, city);
  final friday = day.weekday == 5;
  final dh = t[3];
  final drekaLocal = dh.local % 60 == 0 ? dh.local : (dh.local ~/ 60 + 1) * 60;
  final rows = <PrayerRow>[
    PrayerRow('Imsaku', PrayerKey.imsak, t[0].local, t[0].instant),
    PrayerRow('Sabahu', PrayerKey.sabah, t[1].local, t[1].instant),
    PrayerRow('Lindja e diellit', PrayerKey.sunrise, t[2].local, t[2].instant),
    PrayerRow(friday ? 'Hyrja e xhumasë' : 'Hyrja e drekës', PrayerKey.dhuhr, dh.local, dh.instant),
    PrayerRow(
      friday ? 'Xhumaja' : 'Dreka',
      PrayerKey.dreka,
      drekaLocal,
      dh.instant + (drekaLocal - dh.local) * msPerMinute,
    ),
    PrayerRow('Ikindia', PrayerKey.asr, t[4].local, t[4].instant),
    PrayerRow('Akshami', PrayerKey.maghrib, t[5].local, t[5].instant),
    PrayerRow('Jacia', PrayerKey.isha, t[6].local, t[6].instant),
  ];
  if (_rowsCache.length > 200) _rowsCache.clear();
  return _rowsCache[cacheKey] = rows;
}

PrayerRow rowOf(List<PrayerRow> rows, PrayerKey key) => rows.firstWhere((r) => r.key == key);

// ---------- Forbidden times ----------

class ForbiddenWindow {
  const ForbiddenWindow(this.name, this.start, this.end, this.label);

  final String name;
  final int start;
  final int end;
  final String label;
}

/// Prohibited times: 15 min after sunrise, 10 min before dhuhr begins, 15 min before sunset (Akshami).
List<ForbiddenWindow> forbiddenWindows(List<PrayerRow> rows) {
  ForbiddenWindow w(String name, PrayerRow r, int from, int to) => ForbiddenWindow(
    name,
    r.instant + from * msPerMinute,
    r.instant + to * msPerMinute,
    '${fmtTime(r.local + from)} – ${fmtTime(r.local + to)}',
  );
  return [
    w('Lindja e diellit', rowOf(rows, PrayerKey.sunrise), 0, 15),
    w('Zeniti', rowOf(rows, PrayerKey.dhuhr), -10, 0),
    w('Perëndimi i diellit', rowOf(rows, PrayerKey.maghrib), -15, 0),
  ];
}

// ---------- Sky ----------

/// night = Jacia · dawn = Sabahu · morning = after sunrise · noon = Dreka · afternoon = Ikindia · dusk = Akshami.
enum SkyPhase { night, dawn, morning, noon, afternoon, dusk }

SkyPhase skyPhase(List<PrayerRow> rows, int now) {
  int at(PrayerKey k) => rowOf(rows, k).instant;
  if (now < at(PrayerKey.imsak)) return SkyPhase.night;
  if (now < at(PrayerKey.sunrise)) return SkyPhase.dawn;
  if (now < at(PrayerKey.dhuhr)) return SkyPhase.morning;
  if (now < at(PrayerKey.asr)) return SkyPhase.noon;
  if (now < at(PrayerKey.maghrib)) return SkyPhase.afternoon;
  if (now < at(PrayerKey.isha)) return SkyPhase.dusk;
  return SkyPhase.night;
}

/// Where the sun or moon is, as fractions of the card's width and height.
class OrbState {
  const OrbState({required this.sun, required this.x, required this.y, required this.yFocus, required this.yFull});

  final bool sun;
  final double x;

  /// Normal card.
  final double y;

  /// Taller centred card (prayer list hidden): a flatter arc in its own band of sky above the text.
  final double yFocus;

  /// Full-screen sky: a wide arc between the header and the prayer name.
  final double yFull;
}

/// The sun travels from sunrise to sunset along an arc; the moon from sunset to the next sunrise.
OrbState orbAt(List<PrayerRow> rows, int now) {
  final rise = rowOf(rows, PrayerKey.sunrise).instant;
  final set = rowOf(rows, PrayerKey.maghrib).instant;
  var sun = true;
  double p;
  if (now >= rise && now <= set) {
    p = (now - rise) / (set - rise);
  } else {
    sun = false;
    final from = now > set ? set : set - msPerDay;
    final to = now > set ? rise + msPerDay : rise;
    p = (now - from) / (to - from);
  }
  p = p.clamp(0.0, 1.0);
  final s = math.sin(math.pi * p);
  return OrbState(sun: sun, x: 0.12 + 0.76 * p, y: 0.34 - 0.24 * s, yFocus: 0.16 - 0.08 * s, yFull: 0.3 - 0.1 * s);
}

// ---------- The "next prayer" card ----------

class NextCardModel {
  const NextCardModel({
    required this.forbidden,
    required this.intro,
    required this.name,
    required this.time,
    required this.countdownLabel,
    required this.target,
    this.altText,
    this.altTarget,
  });

  /// True while a forbidden time is running (the card turns red).
  final bool forbidden;
  final String intro;
  final String name;
  final String time;
  final String countdownLabel;

  /// Epoch milliseconds the big countdown runs to.
  final int target;
  final String? altText;
  final int? altTarget;
}

NextCardModel nextCard({required int now, required Day day, required List<PrayerRow> rows, required City city}) {
  var intro = 'Namazi i ardhshëm';
  PrayerRow? next;
  for (final r in rows) {
    if (r.instant > now) {
      next = r;
      break;
    }
  }
  if (next == null) {
    next = dayRows(day.addDays(1), city).first;
    intro = 'Nesër';
  }

  ForbiddenWindow? active;
  for (final w in forbiddenWindows(rows)) {
    if (now >= w.start && now < w.end) {
      active = w;
      break;
    }
  }

  if (active != null) {
    final showNext = next.instant != active.end;
    return NextCardModel(
      forbidden: true,
      intro: 'Kohë e ndaluar për namaz',
      name: active.name,
      time: active.label,
      countdownLabel: 'deri sa të kalojë',
      target: active.end,
      altText: showNext ? 'Namazi i ardhshëm: ${next.name} ${fmtTime(next.local)}' : null,
      altTarget: showNext ? next.instant : null,
    );
  }

  String? altText;
  int? altTarget;
  // After midnight, while waiting for Imsaku, also show when Sabahu can be prayed.
  if (next.key == PrayerKey.imsak && intro != 'Nesër') {
    final sabah = rowOf(rows, PrayerKey.sabah);
    altText = 'Sabahu mund të falet në ${fmtTime(sabah.local)}, pas';
    altTarget = sabah.instant;
  }
  return NextCardModel(
    forbidden: false,
    intro: intro,
    name: next.name,
    time: fmtTime(next.local),
    countdownLabel: 'deri në fillim',
    target: next.instant,
    altText: altText,
    altTarget: altTarget,
  );
}

// ---------- Sabah alarm suggestion ----------

class AlarmModel {
  const AlarmModel(this.time, this.sub);

  final String time;
  final String sub;
}

/// Suggested alarm for Sabahu: a set number of minutes before sunrise (default 30).
/// Shown after Jacia has passed (for tomorrow) and after midnight until the alarm time (for today).
AlarmModel? alarmSuggestion({
  required int now,
  required Day day,
  required List<PrayerRow> rows,
  required City city,
  required int offsetMinutes,
}) {
  ({int local, int instant, int sunrise}) alarmOf(List<PrayerRow> r) {
    final sun = rowOf(r, PrayerKey.sunrise);
    final sabah = rowOf(r, PrayerKey.sabah);
    var local = sun.local - offsetMinutes;
    var instant = sun.instant - offsetMinutes * msPerMinute;
    if (instant < sabah.instant) {
      local = sabah.local;
      instant = sabah.instant;
    }
    return (local: local, instant: instant, sunrise: sun.local);
  }

  final todayAlarm = alarmOf(rows);
  final isha = rowOf(rows, PrayerKey.isha);
  ({int local, int instant, int sunrise})? alarm;
  var when = '';
  if (now >= isha.instant) {
    alarm = alarmOf(dayRows(day.addDays(1), city));
    when = 'Nesër';
  } else if (now < todayAlarm.instant) {
    alarm = todayAlarm;
    when = 'Sot';
  }
  if (alarm == null) return null;
  return AlarmModel(
    fmtTime(alarm.local),
    '$when, $offsetMinutes min para lindjes së diellit (${fmtTime(alarm.sunrise)})',
  );
}

// ---------- Everything the Today screen shows ----------

class TodayModel {
  const TodayModel({
    required this.day,
    required this.isToday,
    required this.rows,
    required this.nextRow,
    required this.card,
    required this.alarm,
    required this.phase,
    required this.orb,
    required this.dayFraction,
  });

  final Day day;
  final bool isToday;
  final List<PrayerRow> rows;

  /// The row to highlight in the list (today only; none once Jacia has passed).
  final PrayerRow? nextRow;
  final NextCardModel? card;
  final AlarmModel? alarm;
  final SkyPhase phase;
  final OrbState orb;

  /// How far through today we are, 0–1 (for the line under the card).
  final double dayFraction;

  bool isPast(PrayerRow r, int now) => isToday && r.instant <= now;
}

TodayModel computeToday({
  required int now,
  required Day today,
  required Day selected,
  required City city,
  required int alarmOffset,
}) {
  final isToday = selected == today;
  final rows = dayRows(selected, city);
  final todayRows = isToday ? rows : dayRows(today, city);
  PrayerRow? nextRow;
  if (isToday) {
    for (final r in rows) {
      if (r.instant > now) {
        nextRow = r;
        break;
      }
    }
  }
  final midnight = today.utcMs - kosovoOffsetForDay(today) * msPerMinute;
  return TodayModel(
    day: selected,
    isToday: isToday,
    rows: rows,
    nextRow: nextRow,
    card: isToday ? nextCard(now: now, day: selected, rows: rows, city: city) : null,
    alarm: isToday
        ? alarmSuggestion(now: now, day: selected, rows: rows, city: city, offsetMinutes: alarmOffset)
        : null,
    phase: skyPhase(todayRows, now),
    orb: orbAt(todayRows, now),
    dayFraction: ((now - midnight) / msPerDay).clamp(0.0, 1.0),
  );
}
