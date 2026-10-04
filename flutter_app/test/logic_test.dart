import 'package:flutter_test/flutter_test.dart';
import 'package:vaktet/src/logic/cities.dart';
import 'package:vaktet/src/logic/day.dart';
import 'package:vaktet/src/logic/format.dart';
import 'package:vaktet/src/logic/prayer.dart';
import 'package:vaktet/src/logic/tips.dart';

int utc(int y, int m, int d, [int h = 0, int min = 0, int s = 0]) =>
    DateTime.utc(y, m, d, h, min, s).millisecondsSinceEpoch;

void main() {
  group('Kosovo time', () {
    test('summer time starts and ends at 01:00 UTC on the last Sundays of March and October', () {
      // 2026: 29 March and 25 October
      expect(kosovoOffsetAt(utc(2026, 3, 29, 0, 59, 59)), 60);
      expect(kosovoOffsetAt(utc(2026, 3, 29, 1)), 120);
      expect(kosovoOffsetAt(utc(2026, 10, 25, 0, 59, 59)), 120);
      expect(kosovoOffsetAt(utc(2026, 10, 25, 1)), 60);
      // other years follow the same rule
      expect(kosovoOffsetAt(utc(2027, 3, 28, 1)), 120);
      expect(kosovoOffsetAt(utc(2028, 10, 29, 1)), 60);
      expect(kosovoOffsetAt(utc(2026, 1, 15, 12)), 60);
      expect(kosovoOffsetAt(utc(2026, 7, 15, 12)), 120);
    });

    test('the date in Kosovo changes at local midnight', () {
      expect(kosovoToday(utc(2026, 1, 1, 22, 59, 59)), const Day(2026, 1, 1));
      expect(kosovoToday(utc(2026, 1, 1, 23)), const Day(2026, 1, 2));
      expect(kosovoToday(utc(2026, 7, 1, 21, 59, 59)), const Day(2026, 7, 1));
      expect(kosovoToday(utc(2026, 7, 1, 22)), const Day(2026, 7, 2));
    });

    test('Day arithmetic', () {
      expect(const Day(2026, 12, 31).addDays(1), const Day(2027, 1, 1));
      expect(const Day(2028, 2, 28).addDays(1), const Day(2028, 2, 29));
      expect(const Day(2026, 10, 3).weekday, 6); // Saturday
      expect(Day.daysInMonth(2028, 2), 29);
      expect(Day.daysInMonth(2026, 2), 28);
    });
  });

  group('Prayer times', () {
    test('Prishtina is one minute earlier than the base times, Dragash two minutes later', () {
      final day = const Day(2026, 10, 3);
      String imsak(City c) => fmtTime(dayTimes(day, c).first.local);
      expect(imsak(cityById('kosove')), '04:53');
      expect(imsak(cityById('prishtine')), '04:52');
      expect(imsak(cityById('dragash')), '04:55');
    });

    test('29 February uses the times of 28 February', () {
      final city = cityById('kosove');
      final a = dayTimes(const Day(2028, 2, 29), city).map((t) => t.local).toList();
      final b = dayTimes(const Day(2028, 2, 28), city).map((t) => t.local).toList();
      expect(a, b);
    });

    test('Dreka is on the full hour, and Friday has Xhumaja', () {
      final city = cityById('kosove');
      final thursday = dayRows(const Day(2026, 10, 1), city);
      final friday = dayRows(const Day(2026, 10, 2), city);
      expect(thursday.map((r) => r.name), contains('Dreka'));
      expect(friday.map((r) => r.name), containsAll(['Xhumaja', 'Hyrja e xhumasë']));
      expect(fmtTime(rowOf(friday, PrayerKey.dhuhr).local), '12:28'); // dhuhr begins at 12:28 in summer time
      expect(fmtTime(rowOf(friday, PrayerKey.dreka).local), '13:00'); // and Dreka is prayed at 13:00 in summer
    });

    test('the card turns to a forbidden time at sunrise and counts down to its end', () {
      final city = cityById('kosove');
      const day = Day(2026, 10, 3);
      final rows = dayRows(day, city);
      final sunrise = rowOf(rows, PrayerKey.sunrise).instant;
      final card = nextCard(now: sunrise + 5 * msPerMinute, day: day, rows: rows, city: city);
      expect(card.forbidden, isTrue);
      expect(card.name, 'Lindja e diellit');
      expect(card.target, sunrise + 15 * msPerMinute);
      final before = nextCard(now: sunrise - msPerMinute, day: day, rows: rows, city: city);
      expect(before.forbidden, isFalse);
      expect(before.name, 'Lindja e diellit');
    });

    test('after Jacia the card shows tomorrow\'s Imsaku and the alarm is for tomorrow', () {
      final city = cityById('kosove');
      const day = Day(2026, 10, 3);
      final rows = dayRows(day, city);
      final now = rowOf(rows, PrayerKey.isha).instant + msPerMinute;
      final card = nextCard(now: now, day: day, rows: rows, city: city);
      expect(card.intro, 'Nesër');
      expect(card.name, 'Imsaku');
      final alarm = alarmSuggestion(now: now, day: day, rows: rows, city: city, offsetMinutes: 30);
      expect(alarm!.sub, startsWith('Nesër, 30 min'));
    });
  });

  group('Text', () {
    test('Hijri date follows the Umm al-Qura calendar and the correction', () {
      expect(hijriText(const Day(2026, 10, 3), 0), '22 Rebiul Ahir 1448 h.');
      expect(hijriText(const Day(2026, 10, 3), 1), '23 Rebiul Ahir 1448 h.');
      expect(hijriText(const Day(2026, 10, 3), -2), '20 Rebiul Ahir 1448 h.');
      expect(hijriText(const Day(1999, 1, 1), 0), '');
    });

    test('long date, countdown and city notes', () {
      expect(longDate(const Day(2026, 10, 3)), 'E shtunë, 3 tetor 2026');
      expect(fmtCount(5300000), '01:28:20');
      expect(fmtCount(-5), '00:00:00');
      expect(monthTitle(2026, 10), 'Tetor 2026');
      expect(cityNote(cityById('kosove')), 'Kohët bazë të Takvimit të Bashkësisë Islame të Kosovës.');
      expect(cityNote(cityById('peje')), 'Pejë: kohët bazë të Takvimit të BIK.');
      expect(cityNote(cityById('prishtine')), 'Prishtinë: 1 minutë më herët se kohët bazë të Takvimit.');
      expect(cityNote(cityById('dragash')), 'Dragash (Sharr): 2 minuta më vonë se kohët bazë të Takvimit.');
    });
  });

  group('Tips', () {
    test('two tips every day, never repeating from one day to the next', () {
      var day = const Day(2026, 10, 1);
      List<String> prev = tipsFor(day).map((t) => t.text).toList();
      for (var i = 0; i < 400; i++) {
        day = day.addDays(1);
        final tips = tipsFor(day);
        expect(tips.length, 2);
        expect(tips[0].text, isNot(tips[1].text));
        final now = tips.map((t) => t.text).toList();
        expect(now.toSet().intersection(prev.toSet()), isEmpty, reason: '$day');
        prev = now;
      }
    });

    test('even days have a tip as a Muslim, odd days two life tips', () {
      final a = tipsFor(const Day(2026, 10, 1)); // day 0
      final b = tipsFor(const Day(2026, 10, 2)); // day 1
      expect(a.map((t) => t.tag), ['Për jetën', 'Si musliman']);
      expect(b.map((t) => t.tag), ['Për jetën', 'Për jetën']);
    });
  });
}
