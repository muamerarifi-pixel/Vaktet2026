// The features that can be switched off, the pulse when a prayer time comes, and how the sky moves.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaktet/src/app.dart';
import 'package:vaktet/src/state/app_controller.dart';
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

  group('Motion', () {
    setUpAll(loadAppFonts);

    /// The app with a moving sky, at 23:00 in Kosovo (stars).
    Future<AppController> open(WidgetTester tester) async {
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

    /// The phone tells the app it went out of sight, or came back.
    Future<void> lifecycle(WidgetTester tester, AppLifecycleState state) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.lifecycle.name,
        SystemChannels.lifecycle.codec.encodeMessage(state.toString()),
        (_) {},
      );
    }

    Future<void> close(WidgetTester tester, AppController c) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      c.dispose();
      expect(SkyClock.shared.running, isFalse);
    }

    testWidgets('the sky moves with every refresh of the screen', (tester) async {
      final c = await open(tester);
      expect(SkyClock.shared.running, isTrue);
      // a ticker of the screen: a new picture on every refresh
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      final before = SkyClock.shared.seconds;
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(microseconds: 16667));
      }
      expect(SkyClock.shared.seconds - before, closeTo(1, .02));
      await close(tester, c);
    });

    testWidgets('it never rests: a minute and more without a touch, it still moves', (tester) async {
      final c = await open(tester);
      for (var i = 0; i < 70; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(SkyClock.shared.running, isTrue);
      final before = SkyClock.shared.seconds;
      await tester.pump(const Duration(milliseconds: 500));
      expect(SkyClock.shared.seconds, greaterThan(before));
      await close(tester, c);
    });

    testWidgets('it moves on under the prayer times, and stops only out of sight', (tester) async {
      final c = await open(tester);
      expect(find.text('VAKTET E SOTME'), findsNothing); // ready, but not shown
      await tester.tap(find.text('Rrëshqit lart për vaktet'));
      await tester.pump(); // the spring starts on this frame
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('VAKTET E SOTME'), findsOneWidget);
      expect(SkyClock.shared.running, isTrue);
      // the app goes out of sight, and comes back
      await lifecycle(tester, AppLifecycleState.paused);
      await tester.pump(const Duration(milliseconds: 100));
      expect(SkyClock.shared.running, isFalse);
      final still = SkyClock.shared.seconds;
      await tester.pump(const Duration(seconds: 5));
      await lifecycle(tester, AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));
      expect(SkyClock.shared.running, isTrue);
      // its time stood still meanwhile, so nothing jumps
      expect(SkyClock.shared.seconds - still, lessThan(.2));
      await close(tester, c);
    });
  });
}
