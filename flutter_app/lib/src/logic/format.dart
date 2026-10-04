/// Albanian text and number formatting.
library;

import '../data/hijri_umalqura.dart';
import 'cities.dart';
import 'day.dart';

const List<String> monthNames = [
  'janar',
  'shkurt',
  'mars',
  'prill',
  'maj',
  'qershor',
  'korrik',
  'gusht',
  'shtator',
  'tetor',
  'nëntor',
  'dhjetor',
];
const List<String> weekdayNames = ['E diel', 'E hënë', 'E martë', 'E mërkurë', 'E enjte', 'E premte', 'E shtunë'];
const List<String> weekdayShort = ['Di', 'Hë', 'Ma', 'Më', 'En', 'Pr', 'Sh'];
const List<String> hijriMonthNames = [
  'Muharrem',
  'Safer',
  'Rebiul Evel',
  'Rebiul Ahir',
  'Xhumadel Ula',
  'Xhumadel Ahire',
  'Rexheb',
  'Shaban',
  'Ramazan',
  'Sheval',
  'Dhul Kade',
  'Dhul Hixhe',
];

String pad2(int n) => n.toString().padLeft(2, '0');

/// Minutes after midnight as `HH:MM`.
String fmtTime(int mins) => '${pad2((mins ~/ 60) % 24)}:${pad2(mins % 60)}';

/// A countdown as `HH:MM:SS` (whole seconds, rounded down).
String fmtCount(int ms) {
  final s = ms <= 0 ? 0 : ms ~/ 1000;
  return '${pad2(s ~/ 3600)}:${pad2((s ~/ 60) % 60)}:${pad2(s % 60)}';
}

String longDate(Day day) => '${weekdayNames[day.weekday]}, ${day.d} ${monthNames[day.m - 1]} ${day.y}';

String monthTitle(int y, int m) => '${monthNames[m - 1][0].toUpperCase()}${monthNames[m - 1].substring(1)} $y';

String cityNote(City c) {
  if (c.off == 0) {
    return c.id == 'kosove'
        ? 'Kohët bazë të Takvimit të Bashkësisë Islame të Kosovës.'
        : '${c.name}: kohët bazë të Takvimit të BIK.';
  }
  final n = c.off.abs();
  return '${c.name}: $n minut${n == 1 ? 'ë' : 'a'} ${c.off < 0 ? 'më herët' : 'më vonë'} se kohët bazë të Takvimit.';
}

/// The Hijri date (Umm al-Qura) of [day], moved by [adj] days, e.g. `22 Rebiul Ahir 1448 h.`.
/// Empty when the date is outside the built-in table (2025–2077).
String hijriText(Day day, int adj) {
  final dayNumber = (day.utcMs + adj * msPerDay + 12 * msPerHour) ~/ msPerDay;
  final starts = hijriMonthStartDays;
  if (dayNumber < starts.first) return '';
  var lo = 0, hi = starts.length - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) >> 1;
    if (starts[mid] <= dayNumber) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  final hd = dayNumber - starts[lo] + 1;
  if (lo == starts.length - 1 && hd > 30) return '';
  final monthIndex = hijriTableFirstMonth - 1 + lo;
  final hy = hijriTableFirstYear + monthIndex ~/ 12;
  final hm = monthIndex % 12 + 1;
  return '$hd ${hijriMonthNames[hm - 1]} $hy h.';
}
