// The features that can be switched off, the pulse when a prayer time comes, and how the sky saves battery.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaktet/src/app.dart';
import 'package:vaktet/src/state/app_controller.dart';
import 'package:vaktet/src/ui/home.dart';
import 'package:vaktet/src/ui/pulse.dart';
import 'package:vaktet/src/ui/sky.dart';

import 'test_fonts.dart';

void main() {
  group('Features', () {
    test('every feature is on at first (but the times on the sky), and switching one off is remembered', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = AppController(prefs: prefs, clock: () => 0);
      for (final f in Feature.values) {
        expect(c.on(f), f != Feature.timesOnSky, reason: f.name);
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

  group('Battery', () {
    setUpAll(loadAppFonts);

    /// The app with a moving sky, at 23:00 in Kosovo (stars), and the phone's battery saver as [powerSave] says.
    Future<AppController> open(WidgetTester tester, StreamController<bool> powerSave) async {
      tester.binding.defaultBinaryMessenger.setMockStreamHandler(
        const EventChannel('vaktet/power_save'),
        MockStreamHandler.inline(
          onListen: (_, events) {
            powerSave.stream.listen(events.success);
          },
        ),
      );
      SharedPreferences.setMockInitialValues({});
      final at = DateTime.utc(2026, 10, 6, 21).millisecondsSinceEpoch;
      final c = AppController(prefs: await SharedPreferences.getInstance(), clock: () => at);
      tester.view.physicalSize = const Size(390, 844) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(VaktetApp(controller: c));
      await tester.pump(const Duration(milliseconds: 100));
      return c;
    }

    Future<void> close(WidgetTester tester, AppController c) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      c.dispose();
      expect(SkyClock.shared.running, isFalse);
    }

    testWidgets('the sky moves on a 20-a-second clock, with no ticker at the rate of the screen', (tester) async {
      final power = StreamController<bool>();
      final c = await open(tester, power);
      expect(SkyClock.shared.running, isTrue);
      // a ticker would ask for a picture on every refresh of the screen, even with nothing new to show
      expect(tester.binding.transientCallbackCount, 0);
      final before = SkyClock.shared.seconds;
      await tester.pump(const Duration(seconds: 1));
      expect(SkyClock.shared.seconds - before, closeTo(1, .06));
      await close(tester, c);
      await power.close();
    });

    testWidgets('the sky rests 30 seconds after the last touch, and a touch wakes it', (tester) async {
      final power = StreamController<bool>();
      final c = await open(tester, power);
      await tester.pump(HomePage.restAfter - const Duration(seconds: 1));
      expect(SkyClock.shared.running, isTrue);
      await tester.pump(const Duration(seconds: 2));
      expect(SkyClock.shared.running, isFalse);
      final still = SkyClock.shared.seconds;
      await tester.pump(const Duration(seconds: 5));
      expect(SkyClock.shared.seconds, still); // its time stands still, so nothing jumps when it wakes
      await tester.tapAt(const Offset(200, 420));
      await tester.pump(const Duration(milliseconds: 100));
      expect(SkyClock.shared.running, isTrue);
      // switched off in the settings, it never rests
      c.setFeature(Feature.skyRest, false);
      await tester.pump(HomePage.restAfter + const Duration(seconds: 5));
      expect(SkyClock.shared.running, isTrue);
      await close(tester, c);
      await power.close();
    });

    testWidgets('the sky is still while the phone saves battery, and under the prayer times', (tester) async {
      final power = StreamController<bool>();
      final c = await open(tester, power);
      power.add(true);
      await tester.pump(const Duration(milliseconds: 100));
      expect(SkyClock.shared.running, isFalse);
      power.add(false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(SkyClock.shared.running, isTrue);
      expect(find.text('VAKTET E SOTME'), findsNothing); // ready, but not shown
      await tester.tap(find.text('Rrëshqit lart për vaktet'));
      await tester.pump(); // the spring starts on this frame
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('VAKTET E SOTME'), findsOneWidget);
      expect(SkyClock.shared.running, isFalse);
      await close(tester, c);
      await power.close();
    });
  });
}
