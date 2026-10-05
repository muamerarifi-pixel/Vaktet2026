// The real Moon and the hours of the sky.
import 'package:flutter_test/flutter_test.dart';
import 'package:vaktet/src/logic/cities.dart';
import 'package:vaktet/src/logic/day.dart';
import 'package:vaktet/src/logic/prayer.dart';
import 'package:vaktet/src/logic/sky_scene.dart';

int utc(int y, int m, int d, [int h = 0, int min = 0]) => DateTime.utc(y, m, d, h, min).millisecondsSinceEpoch;

void main() {
  group('Moon phase', () {
    test('eclipses fall on new and full moons', () {
      // total lunar eclipse, 3 March 2026
      expect(moonPhase(utc(2026, 3, 3, 11, 33)).illumination, greaterThan(.995));
      // total solar eclipses, 12 August 2026 and 2 August 2027
      expect(moonPhase(utc(2026, 8, 12, 17, 46)).illumination, lessThan(.005));
      expect(moonPhase(utc(2027, 8, 2, 10, 7)).illumination, lessThan(.005));
    });

    test('waxing after the new moon, waning after the full moon', () {
      final waxing = moonPhase(utc(2026, 10, 18, 19));
      expect(waxing.waxing, isTrue);
      expect(waxing.illumination, closeTo(.5, .1)); // first quarter
      final waning = moonPhase(utc(2026, 10, 5, 19));
      expect(waning.waxing, isFalse);
      expect(waning.illumination, inInclusiveRange(.15, .4)); // a waning crescent
    });

    test('the full moon rises at sunset and is up all night; the new moon travels with the sun', () {
      final full = const Day(2026, 10, 26);
      final rows = dayRows(full, cityById(null));
      expect(moonAt(rows, utc(2026, 10, 25, 23)).up, isTrue); // midnight in Kosovo
      expect(moonAt(rows, utc(2026, 10, 26, 11)).up, isFalse); // noon
      final newMoon = dayRows(const Day(2026, 10, 10), cityById(null));
      expect(moonAt(newMoon, utc(2026, 10, 10, 10)).up, isTrue);
      expect(moonAt(newMoon, utc(2026, 10, 9, 23)).up, isFalse);
    });
  });

  group('Hours of the sky', () {
    final rows = dayRows(const Day(2026, 10, 5), cityById(null));
    final rise = rowOf(rows, PrayerKey.sunrise).instant;
    final set = rowOf(rows, PrayerKey.maghrib).instant;

    test('sunrise is hour 6, sunset hour 18, and the middle of the day hour 12', () {
      expect(temporalHour(rows, rise), closeTo(6, 1e-9));
      expect(temporalHour(rows, set), closeTo(18, 1e-9));
      expect(temporalHour(rows, (rise + set) ~/ 2), closeTo(12, 1e-6));
      for (var t = utc(2026, 10, 4, 22); t < utc(2026, 10, 5, 22); t += 15 * msPerMinute) {
        final h = temporalHour(rows, t);
        expect(h, inInclusiveRange(0, 24));
      }
    });

    test('every hour looks a little different', () {
      final tints = <int>{};
      for (var t = utc(2026, 10, 4, 22); t < utc(2026, 10, 5, 22); t += msPerHour) {
        tints.add(skySceneAt(rows, t, const Day(2026, 10, 5)).tint);
      }
      expect(tints.length, 24);
    });

    test('lights in the villages at night, mist and birds in the morning, fireflies only in summer', () {
      const day = Day(2026, 10, 5);
      final evening = skySceneAt(rows, set + 90 * msPerMinute, day);
      expect(evening.townLights, greaterThan(.9));
      expect(evening.mist, 0);
      final morning = skySceneAt(rows, rise + 40 * msPerMinute, day);
      expect(morning.townLights, 0);
      expect(morning.mist, greaterThan(.5));
      expect(morning.birds, greaterThan(0));
      final noon = skySceneAt(rows, (rise + set) ~/ 2, day);
      expect(noon.plane, 1);
      expect(noon.milkyWay, 0);
      final midnight = skySceneAt(rows, utc(2026, 10, 5, 0), day);
      expect(midnight.milkyWay, 1);
      expect(evening.fireflies, 0);
      final july = dayRows(const Day(2026, 7, 5), cityById(null));
      final summer = skySceneAt(july, rowOf(july, PrayerKey.maghrib).instant + 70 * msPerMinute, const Day(2026, 7, 5));
      expect(summer.fireflies, greaterThan(0));
    });

    test('the scene only changes a few hundred times a day (the sky is not repainted every second)', () {
      const day = Day(2026, 10, 5);
      var changes = 0;
      SkyScene? last;
      for (var t = utc(2026, 10, 4, 22); t < utc(2026, 10, 5, 22); t += 1000) {
        final s = skySceneAt(rows, t, day);
        if (s != last) changes++;
        last = s;
      }
      expect(changes, lessThan(4000));
    });
  });
}
