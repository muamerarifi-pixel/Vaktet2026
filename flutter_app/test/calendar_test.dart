// The notes of the days, checked against the BIK Takvim 2026 and Kosovo's law on official holidays.
import 'package:flutter_test/flutter_test.dart';
import 'package:vaktet/src/logic/calendar_notes.dart';
import 'package:vaktet/src/logic/cities.dart';
import 'package:vaktet/src/logic/day.dart';
import 'package:vaktet/src/logic/prayer.dart';

List<String> _notes(int m, int d, [int y = 2026]) => [for (final n in notesFor(Day(y, m, d))) n.text];

void main() {
  test('the Hijri date follows the BIK Takvim', () {
    expect(hijriLabel(const Day(2026, 1, 1), 0), '12 Rexheb 1447 h.');
    expect(hijriLabel(const Day(2026, 2, 18), 0), '30 Shaban 1447 h.'); // Umm al-Qura: 1 Ramazan
    expect(hijriLabel(const Day(2026, 2, 19), 0), '1 Ramazan 1447 h.');
    expect(hijriLabel(const Day(2026, 3, 20), 0), '1 Sheval 1447 h.');
    expect(hijriLabel(const Day(2026, 10, 3), 0), '22 Rebiul Ahir 1448 h.');
    expect(hijriLabel(const Day(2026, 11, 10), 0), '1 Xhumadel Ahire 1448 h.'); // Umm al-Qura: 30 Xhumadel Ula
    expect(hijriLabel(const Day(2026, 11, 23), 0), '14 Xhumadel Ahire 1448 h.');
    expect(hijriLabel(const Day(2026, 12, 10), 0), '1 Rexheb 1448 h.');
    expect(hijriLabel(const Day(2026, 10, 3), 1), '23 Rebiul Ahir 1448 h.');
    expect(hijriLabel(const Day(1999, 1, 1), 0), '');
  });

  test('the great nights and days of 1447–1448 fall where the Takvim puts them', () {
    expect(_notes(1, 15), contains('Nata e Miraxhit'));
    expect(_notes(2, 2), containsAll(['Nata e Beratit', 'Hëna e plotë']));
    expect(_notes(2, 18), contains('Nata e Ramazanit – teravia e parë'));
    expect(_notes(2, 19), containsAll(['Dita e parë e Ramazanit', 'Hëna e re', 'Xhemra I në ajër']));
    expect(_notes(3, 7), containsAll(['Dita e fitores në Bedër', 'Dita e mësuesit']));
    expect(_notes(3, 16), contains('Nata e Kadrit'));
    expect(_notes(3, 19), contains('Nata e Fitër Bajramit'));
    expect(_notes(3, 20), contains('Dita e I e Fitër Bajramit'));
    expect(_notes(3, 22), contains('Dita e III e Fitër Bajramit'));
    expect(_notes(5, 26), containsAll(['Dita e Arafatit', 'Nata e Kurban Bajramit']));
    expect(_notes(5, 27), contains('Dita e I e Kurban Bajramit'));
    expect(_notes(5, 30), contains('Dita e IV e Kurban Bajramit'));
    expect(_notes(6, 16), containsAll(['Viti i Ri sipas Hixhretit 1448', 'Hëna e re']));
    expect(_notes(6, 25), contains('Dita e Ashurës'));
    expect(_notes(8, 24), contains('Nata e Mevludit'));
    expect(_notes(8, 25), contains('Ditëlindja e Muhamedit a.s.'));
    expect(_notes(12, 10), containsAll(['Nata e Regaibit', 'Hëna e re']));
    // nothing on an ordinary day
    expect(_notes(10, 8), isEmpty);
  });

  test('the other notes of the Takvim', () {
    expect(_notes(3, 29), contains('Kalimi në kohën verore +1 orë'));
    expect(_notes(10, 25), containsAll(['Kalimi në kohën dimërore −1 orë', 'Hëna e plotë']));
    expect(_notes(6, 20), contains('Dita më e gjatë e vitit (15 orë e 35 min.)'));
    expect(_notes(12, 21), contains('Dita më e shkurtër e vitit (9 orë e 14 min.)'));
    expect(_notes(12, 22), containsAll(['Arbaini', 'Dimri']));
    expect(_notes(3, 21), contains('Pranvera'));
    expect(_notes(8, 2), contains('Aligjyni'));
  });

  test('Kosovo: official holidays, Easter and the day off after a weekend holiday', () {
    expect(_notes(2, 17), contains('Dita e Pavarësisë së Kosovës'));
    expect(notesFor(const Day(2026, 2, 17)).first.holiday, isTrue);
    expect(_notes(11, 28), contains('Dita e Flamurit kombëtar'));
    expect(westernEaster(2026), const Day(2026, 4, 5));
    expect(orthodoxEaster(2026), const Day(2026, 4, 12));
    expect(westernEaster(2027), const Day(2027, 3, 28));
    expect(orthodoxEaster(2027), const Day(2027, 5, 2));
    expect(_notes(4, 5), contains('Pashkët katolike'));
    // both Easters fall on a Sunday: the Monday after is a day off
    expect(_notes(4, 6), contains('Ditë pushimi për Pashkët katolike'));
    expect(_notes(4, 13), contains('Ditë pushimi për Pashkët ortodokse'));
    // 9 May 2026 is a Saturday
    expect(_notes(5, 11), contains('Ditë pushimi për Dita e Evropës'));
    expect(isDayOff(const Day(2026, 5, 11)), isTrue);
    expect(isDayOff(const Day(2026, 5, 12)), isFalse);
  });

  group('Nafile prayers', () {
    const day = Day(2026, 10, 3);
    final rows = dayRows(day, cities.first);
    int at(int h, int m) => DateTime.utc(2026, 10, 3, h - 2, m).millisecondsSinceEpoch; // Kosovo time

    NafileHint? hint(int h, int m) => nafileAt(now: at(h, m), day: day, rows: rows, city: cities.first);

    test('Duha in the morning, Evvabin after Akshami, Tehexhud late in the night', () {
      expect(hint(9, 0)?.name, 'Duha');
      expect(hint(6, 30), isNull); // the sun has only just risen
      expect(hint(12, 25), isNull); // just before noon
      expect(hint(18, 45)?.name, 'Evvabin');
      expect(hint(21, 0), isNull);
      expect(hint(3, 30)?.name, 'Tehexhud');
      expect(hint(4, 55), isNull); // Imsaku has come
    });
  });
}
