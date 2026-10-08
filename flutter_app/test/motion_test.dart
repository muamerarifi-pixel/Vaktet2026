// The features that can be switched off, and the pulse when a prayer time comes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaktet/src/state/app_controller.dart';
import 'package:vaktet/src/ui/pulse.dart';

void main() {
  group('Features', () {
    test('every feature is on at first, and switching one off is remembered', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = AppController(prefs: prefs, clock: () => 0);
      for (final f in Feature.values) {
        expect(c.on(f), isTrue, reason: f.name);
      }
      final before = c.settingsVersion.value;
      c.setFeature(Feature.nafile, false);
      expect(c.on(Feature.nafile), isFalse);
      expect(prefs.getBool('f_nafile'), isFalse);
      expect(c.settingsVersion.value, before + 1);
      c.dispose();
      final again = AppController(prefs: prefs, clock: () => 0);
      expect(again.on(Feature.nafile), isFalse);
      again.dispose();
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
