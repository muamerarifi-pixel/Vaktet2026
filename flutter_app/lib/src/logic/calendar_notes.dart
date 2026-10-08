/// The calendar around the prayer times: the Hijri date as the BIK Takvim gives it, Kosovo's national days,
/// the great Islamic nights and days, the other notes of the Takvim (seasons, the moon, the xhemre …), and the
/// times of the voluntary (nafile) prayers.
library;

import '../data/hijri_umalqura.dart';
import 'cities.dart';
import 'day.dart';
import 'format.dart';
import 'prayer.dart';

// ---------- The Hijri date ----------

class HijriDate {
  const HijriDate(this.y, this.m, this.d);

  final int y;

  /// 1 = Muharrem … 12 = Dhul Hixhe.
  final int m;
  final int d;

  @override
  bool operator ==(Object other) => other is HijriDate && other.y == y && other.m == m && other.d == d;

  @override
  int get hashCode => Object.hash(y, m, d);

  @override
  String toString() => '$d ${hijriMonthNames[m - 1]} $y h.';
}

int _tableIndex(int y, int m) => (y - hijriTableFirstYear) * 12 + (m - 1) - (hijriTableFirstMonth - 1);

/// The months in which the BIK Takvim starts on another day than Umm al-Qura (Takvimi 1447–1448, botimi 2026).
final Map<int, int> _bikMonthStarts = {
  _tableIndex(1447, 9): const Day(2026, 2, 19).epochDay, // Ramazani 1447 (Umm al-Qura: 18 shkurt)
  _tableIndex(1448, 6): const Day(2026, 11, 10).epochDay, // Xhumadel Ahire 1448 (Umm al-Qura: 11 nëntor)
};

int _monthStart(int i, bool official) => (official ? _bikMonthStarts[i] : null) ?? hijriMonthStartDays[i];

/// The Hijri date of [day], moved by [adj] days. With [official], the months start as in the BIK Takvim where it
/// differs from Umm al-Qura. Null outside the built-in table (2025–2077).
HijriDate? hijriOf(Day day, int adj, {bool official = true}) {
  final dayNumber = (day.utcMs + adj * msPerDay + 12 * msPerHour) ~/ msPerDay;
  final n = hijriMonthStartDays.length;
  if (dayNumber < _monthStart(0, official)) return null;
  var lo = 0, hi = n - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) >> 1;
    if (_monthStart(mid, official) <= dayNumber) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  final hd = dayNumber - _monthStart(lo, official) + 1;
  if (lo == n - 1 && hd > 30) return null;
  final monthIndex = hijriTableFirstMonth - 1 + lo;
  return HijriDate(hijriTableFirstYear + monthIndex ~/ 12, monthIndex % 12 + 1, hd);
}

/// The Hijri date as the app shows it (the BIK Takvim's months), e.g. `22 Rebiul Ahir 1448 h.`.
String hijriLabel(Day day, int adj) => hijriOf(day, adj)?.toString() ?? '';

// ---------- The notes of a day ----------

enum NoteKind {
  /// Kosovo's official holidays and national days.
  national,

  /// The great Islamic nights and days.
  islamic,

  /// The other notes of the BIK Takvim: the seasons, the moon, the xhemre, summer time …
  takvim,
}

class DayNote {
  const DayNote(this.text, this.kind, {this.holiday = false, this.night = false});

  final String text;
  final NoteKind kind;

  /// An official holiday (a day off).
  final bool holiday;

  /// A night that begins on the evening of this day.
  final bool night;

  @override
  bool operator ==(Object other) =>
      other is DayNote && other.text == text && other.kind == kind && other.holiday == holiday && other.night == night;

  @override
  int get hashCode => Object.hash(text, kind, holiday, night);

  @override
  String toString() => text;
}

/// Easter Sunday in the Gregorian calendar (the anonymous Gregorian algorithm).
Day westernEaster(int y) {
  final a = y % 19, b = y ~/ 100, c = y % 100, d = b ~/ 4, e = b % 4;
  final f = (b + 8) ~/ 25, g = (b - f + 1) ~/ 3, h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4, k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31, day = (h + l - 7 * m + 114) % 31 + 1;
  return Day(y, month, day);
}

/// Orthodox Easter Sunday (the Julian computus, moved to the Gregorian calendar; 1900–2099).
Day orthodoxEaster(int y) {
  final a = y % 4, b = y % 7, c = y % 19;
  final d = (19 * c + 15) % 30, e = (2 * a + 4 * b - d + 34) % 7;
  final month = (d + e + 114) ~/ 31, day = (d + e + 114) % 31 + 1;
  return Day(y, month, day).addDays(13);
}

/// Kosovo's official holidays and memorial days that fall on the same date every year: (month, day, name, day off).
const List<(int, int, String, bool)> _fixedNational = [
  (1, 1, 'Viti i Ri', true),
  (1, 2, 'Viti i Ri – dita e dytë', true),
  (1, 7, 'Krishtlindjet ortodokse', true),
  (2, 15, 'Dita e Ashkalinjve', false),
  (2, 17, 'Dita e Pavarësisë së Kosovës', true),
  (3, 5, 'Përvjetori i Epopesë së UÇK-së', false),
  (3, 6, 'Dita e Veteranëve të Luftës', false),
  (3, 7, 'Dita e mësuesit', false),
  (4, 8, 'Dita e Romëve', false),
  (4, 9, 'Dita e Kushtetutës së Kosovës', true),
  (4, 23, 'Dita e Turqve', false),
  (5, 1, 'Dita Ndërkombëtare e Punës', true),
  (5, 6, 'Dita e Goranëve', false),
  (5, 9, 'Dita e Evropës', true),
  (6, 12, 'Dita e Paqes – çlirimi i Kosovës', false),
  (9, 28, 'Dita e Boshnjakëve', false),
  (11, 22, 'Dita e Alfabetit të gjuhës shqipe', false),
  (11, 28, 'Dita e Flamurit kombëtar', false),
  (12, 25, 'Krishtlindjet katolike', true),
];

/// The other notes of the Takvim that come on the same date every year.
const List<(int, int, String)> _fixedTakvim = [
  (1, 31, 'Hamsini'),
  (2, 19, 'Xhemra I në ajër'),
  (2, 25, 'Xhemra II në ujë'),
  (3, 5, 'Xhemra III në tokë'),
  (3, 21, 'Pranvera'),
  (6, 22, 'Vera'),
  (8, 2, 'Aligjyni'),
  (8, 6, 'Gjysma e verës'),
  (9, 23, 'Vjeshta'),
  (12, 22, 'Arbaini'),
  (12, 22, 'Dimri'),
];

const List<String> _ordinal = ['I', 'II', 'III', 'IV'];

/// The great Islamic nights and days of [day]. A night is given on the evening it begins.
List<DayNote> _islamicNotes(Day day, int adj) {
  final h = hijriOf(day, adj);
  final next = hijriOf(day.addDays(1), adj);
  if (h == null || next == null) return const [];
  final out = <DayNote>[];
  void night(String text) => out.add(DayNote(text, NoteKind.islamic, night: true));
  void dayNote(String text, {bool holiday = false}) => out.add(DayNote(text, NoteKind.islamic, holiday: holiday));

  // the days
  if (h.m == 1 && h.d == 1) dayNote('Viti i Ri sipas Hixhretit ${h.y}');
  if (h.m == 1 && h.d == 10) dayNote('Dita e Ashurës');
  if (h.m == 3 && h.d == 12) dayNote('Ditëlindja e Muhamedit a.s.');
  if (h.m == 9 && h.d == 1) dayNote('Dita e parë e Ramazanit');
  if (h.m == 9 && h.d == 17) dayNote('Dita e fitores në Bedër');
  if (h.m == 9 && h.d == 20) dayNote('Dita e çlirimit të Mekës, I\'tikjafi');
  if (h.m == 10 && h.d <= 3) dayNote('Dita e ${_ordinal[h.d - 1]} e Fitër Bajramit', holiday: h.d == 1);
  if (h.m == 12 && h.d == 9) dayNote('Dita e Arafatit');
  if (h.m == 12 && h.d >= 10 && h.d <= 13) {
    dayNote('Dita e ${_ordinal[h.d - 10]} e Kurban Bajramit', holiday: h.d == 10);
  }

  // the nights, on the evening before their day
  if (next.m == 7 && next.d == 27) night('Nata e Miraxhit');
  if (next.m == 8 && next.d == 15) night('Nata e Beratit');
  if (next.m == 9 && next.d == 1) night('Nata e Ramazanit – teravia e parë');
  if (next.m == 9 && next.d == 27) night('Nata e Kadrit');
  if (next.m == 10 && next.d == 1) night('Nata e Fitër Bajramit');
  if (next.m == 12 && next.d == 10) night('Nata e Kurban Bajramit');
  if (next.m == 3 && next.d == 12) night('Nata e Mevludit');
  // the night before the first Friday of Rexheb
  if (day.weekday == 4 && next.m == 7 && next.d <= 7) night('Nata e Regaibit');
  return out;
}

/// Official holidays (a day off) in [year]: the fixed ones, both Easters and both Bajrams.
List<(Day, String)> _holidaysOf(int year, int adj) {
  final out = <(Day, String)>[
    for (final (m, d, name, off) in _fixedNational)
      if (off) (Day(year, m, d), name),
    (westernEaster(year), 'Pashkët katolike'),
    (orthodoxEaster(year), 'Pashkët ortodokse'),
  ];
  // the first days of the Bajrams
  var d = Day(year, 1, 1);
  while (d.y == year) {
    final h = hijriOf(d, adj);
    if (h != null && h.d == 1 && h.m == 10) out.add((d, 'Fitër Bajrami'));
    if (h != null && h.d == 10 && h.m == 12) out.add((d, 'Kurban Bajrami'));
    d = d.addDays(1);
  }
  out.sort((a, b) => a.$1.epochDay.compareTo(b.$1.epochDay));
  return out;
}

final Map<String, Map<int, String>> _daysOffCache = {};

/// When an official holiday falls on a Saturday or a Sunday, the next working day is a day off.
Map<int, String> _movedDaysOff(int year, int adj) {
  final key = '$year:$adj';
  final hit = _daysOffCache[key];
  if (hit != null) return hit;
  final holidays = _holidaysOf(year, adj);
  final taken = {for (final (d, _) in holidays) d.epochDay};
  final out = <int, String>{};
  for (final (d, name) in holidays) {
    if (d.weekday != 0 && d.weekday != 6) continue;
    var x = d.addDays(1);
    while (x.weekday == 0 || x.weekday == 6 || taken.contains(x.epochDay) || out.containsKey(x.epochDay)) {
      x = x.addDays(1);
    }
    out[x.epochDay] = name;
  }
  if (_daysOffCache.length > 8) _daysOffCache.clear();
  return _daysOffCache[key] = out;
}

int _dayLength(Day day, City city) {
  final t = dayTimes(day, city);
  return t[5].local - t[2].local;
}

String _hoursAndMinutes(int mins) => '${mins ~/ 60} orë e ${mins % 60} min.';

/// The last Sunday of [month] in [year].
Day _lastSunday(int year, int month) {
  final last = Day(year, month, Day.daysInMonth(year, month));
  return last.addDays(-last.weekday);
}

final Map<String, List<DayNote>> _notesCache = {};

/// Everything the calendar notes for [day]: national days first, then the Islamic ones, then the Takvim's own.
List<DayNote> notesFor(Day day, {int hijriAdj = 0, City city = const City('kosove', 'Kosovë', 0)}) {
  final key = '$day:$hijriAdj:${city.id}';
  final hit = _notesCache[key];
  if (hit != null) return hit;
  final out = <DayNote>[];

  // Kosovo
  for (final (m, d, name, off) in _fixedNational) {
    if (day.m == m && day.d == d) out.add(DayNote(name, NoteKind.national, holiday: off));
  }
  if (day == westernEaster(day.y)) out.add(const DayNote('Pashkët katolike', NoteKind.national, holiday: true));
  if (day == orthodoxEaster(day.y)) out.add(const DayNote('Pashkët ortodokse', NoteKind.national, holiday: true));
  final moved = _movedDaysOff(day.y, hijriAdj)[day.epochDay];
  if (moved != null) out.add(DayNote('Ditë pushimi për $moved', NoteKind.national, holiday: true));

  out.addAll(_islamicNotes(day, hijriAdj));

  // the Takvim
  final h = hijriOf(day, hijriAdj);
  if (h != null && h.d == 1) out.add(const DayNote('Hëna e re', NoteKind.takvim));
  if (h != null && h.d == 14) out.add(const DayNote('Hëna e plotë', NoteKind.takvim));
  for (final (m, d, text) in _fixedTakvim) {
    if (day.m == m && day.d == d) out.add(DayNote(text, NoteKind.takvim));
  }
  if (day.m == 6 && day.d == 20) {
    out.add(DayNote('Dita më e gjatë e vitit (${_hoursAndMinutes(_dayLength(day, city))})', NoteKind.takvim));
  }
  if (day.m == 12 && day.d == 21) {
    out.add(DayNote('Dita më e shkurtër e vitit (${_hoursAndMinutes(_dayLength(day, city))})', NoteKind.takvim));
  }
  if (day == _lastSunday(day.y, 3)) out.add(const DayNote('Kalimi në kohën verore +1 orë', NoteKind.takvim));
  if (day == _lastSunday(day.y, 10)) out.add(const DayNote('Kalimi në kohën dimërore −1 orë', NoteKind.takvim));

  if (_notesCache.length > 400) _notesCache.clear();
  return _notesCache[key] = List.unmodifiable(out);
}

/// Whether [day] is an official holiday or a day off in Kosovo.
bool isDayOff(Day day, {int hijriAdj = 0}) => notesFor(day, hijriAdj: hijriAdj).any((n) => n.holiday);

// ---------- Nafile prayers ----------

class NafileHint {
  const NafileHint(this.name, this.text);

  /// Duha, Evvabin or Tehexhud.
  final String name;
  final String text;
}

/// A voluntary prayer whose time it is now: Duha in the morning, Evvabin between Akshami and Jacia, Tehexhud in
/// the last third of the night.
NafileHint? nafileAt({required int now, required Day day, required List<PrayerRow> rows, required City city}) {
  final sunrise = rowOf(rows, PrayerKey.sunrise), dhuhr = rowOf(rows, PrayerKey.dhuhr);
  final maghrib = rowOf(rows, PrayerKey.maghrib), isha = rowOf(rows, PrayerKey.isha);
  final imsak = rowOf(rows, PrayerKey.imsak);

  // Duha: from when the sun is well up (after the forbidden time) until a little before noon
  final duhaFrom = sunrise.instant + 20 * msPerMinute, duhaTo = dhuhr.instant - 10 * msPerMinute;
  if (now >= duhaFrom && now < duhaTo) {
    return NafileHint('Duha', 'Koha e namazit Duha (nafile), deri në ${fmtTime(dhuhr.local - 10)}');
  }
  // Evvabin: after the Akshami prayer, until Jacia
  if (now >= maghrib.instant + 10 * msPerMinute && now < isha.instant) {
    return NafileHint('Evvabin', 'Koha e namazit Evvabin (nafile), deri në ${fmtTime(isha.local)}');
  }
  // Tehexhud: the last third of the night, from Akshami to Imsaku
  final ({int from, int to, int toLocal})? night = now < imsak.instant
      ? (
          from: rowOf(dayRows(day.addDays(-1), city), PrayerKey.maghrib).instant,
          to: imsak.instant,
          toLocal: imsak.local,
        )
      : now >= maghrib.instant
      ? () {
          final next = rowOf(dayRows(day.addDays(1), city), PrayerKey.imsak);
          return (from: maghrib.instant, to: next.instant, toLocal: next.local);
        }()
      : null;
  if (night != null) {
    final lastThird = night.to - (night.to - night.from) ~/ 3;
    if (now >= lastThird && now < night.to) {
      return NafileHint('Tehexhud', 'Koha e namazit të natës, Tehexhud (nafile), deri në ${fmtTime(night.toLocal)}');
    }
  }
  return null;
}
