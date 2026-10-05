// The tilt of the sky and the pulse when a prayer time comes.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaktet/src/state/app_controller.dart';
import 'package:vaktet/src/ui/pulse.dart';
import 'package:vaktet/src/ui/sky.dart';

void main() {
  group('Tilt', () {
    test('tilting moves the sky a little, holding still lets it drift back, and it never goes too far', () async {
      final sensor = StreamController<Offset>();
      final tilt = SkyTilt(() => sensor.stream);
      tilt.start();
      sensor.add(const Offset(0, 9)); // held upright
      await Future<void>.delayed(Duration.zero);
      expect(tilt.value, Offset.zero);
      for (var i = 0; i < 20; i++) {
        sensor.add(const Offset(6, 9)); // tilted to the side
        await Future<void>.delayed(Duration.zero);
      }
      expect(tilt.value.dx, lessThan(-3));
      expect(tilt.value.distance, lessThanOrEqualTo(SkyTilt.reach + .001));
      for (var i = 0; i < 600; i++) {
        sensor.add(const Offset(6, 9)); // held there
        await Future<void>.delayed(Duration.zero);
      }
      expect(tilt.value.dx.abs(), lessThan(1));
      tilt.stop();
      expect(tilt.value, Offset.zero);
      tilt.dispose();
      await sensor.close();
    });

    test('no sensor: nothing happens', () {
      final tilt = SkyTilt(() => throw UnsupportedError('no sensor'));
      tilt.start();
      expect(tilt.running, isFalse);
      tilt.dispose();
    });

    test('the choice is remembered', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = AppController(prefs: prefs, clock: () => 0);
      expect(c.tilt, isTrue);
      c.setTilt(false);
      expect(prefs.getBool('tilt'), isFalse);
      c.dispose();
    });
  });

  group('Prayer pulse', () {
    Future<PrayerPulseState> pump(WidgetTester tester, int? target, int now, {bool enabled = true}) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: PrayerPulse(target: target, now: now, enabled: enabled),
        ),
      );
      return tester.state<PrayerPulseState>(find.byType(PrayerPulse));
    }

    testWidgets('runs once when the countdown reaches its prayer time, then fades away', (tester) async {
      await pump(tester, 1000000, 999000);
      final s = await pump(tester, 2000000, 1000400); // the time came; the countdown moved on
      expect(s.running, isTrue);
      await tester.pump(const Duration(seconds: 3));
      expect(s.running, isFalse);
    });

    testWidgets('not when the countdown changes for another reason (city, day)', (tester) async {
      await pump(tester, 1000000, 500000);
      final s = await pump(tester, 1060000, 500400);
      expect(s.running, isFalse);
    });

    testWidgets('not when the phone asks for less motion', (tester) async {
      await pump(tester, 1000000, 999000, enabled: false);
      final s = await pump(tester, 2000000, 1000400, enabled: false);
      expect(s.running, isFalse);
    });
  });
}
