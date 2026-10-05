// The layouts must never overflow, on small phones with large text, on tablets, in every view and mode.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaktet/src/app.dart';
import 'package:vaktet/src/state/app_controller.dart';

import 'test_fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  const sizes = [Size(320, 568), Size(360, 640), Size(412, 915), Size(768, 1024), Size(1280, 800)];
  const scales = [1.0, 1.3];
  // a time in each part of the day, and one with a forbidden time
  final instants = {
    'night': DateTime.utc(2026, 10, 3, 23, 30),
    'dawn': DateTime.utc(2026, 10, 3, 3, 30),
    'forbidden': DateTime.utc(2026, 10, 3, 4, 31),
    'noon': DateTime.utc(2026, 10, 3, 10, 30),
    'dusk': DateTime.utc(2026, 10, 3, 16, 38),
  };

  for (final size in sizes) {
    for (final scale in scales) {
      testWidgets('no overflow at ${size.width.toInt()}x${size.height.toInt()}, text ×$scale', (tester) async {
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);

        for (final dark in [false, true]) {
          for (final entry in instants.entries) {
            for (final mode in ['today', 'other day']) {
              SharedPreferences.setMockInitialValues({
                'city': 'dragash', // the longest city name
                'theme': dark ? 'dark' : 'light',
              });
              final controller = AppController(
                prefs: await SharedPreferences.getInstance(),
                clock: () => entry.value.millisecondsSinceEpoch,
              );
              if (mode == 'other day') controller.select(controller.today.addDays(1));
              await tester.pumpWidget(VaktetApp(controller: controller, skyMotion: false));
              await tester.pump(const Duration(milliseconds: 50));
              expect(tester.takeException(), isNull, reason: '${entry.key} $mode dark=$dark');
              if (size.width < 900) {
                // the prayer times swiped up over the sky
                await tester.pumpAndSettle();
                await tester.tap(find.bySemanticsLabel('Shfaq vaktet e sotme'), warnIfMissed: false);
                await tester.pumpAndSettle();
                expect(find.textContaining('VAKTET E '), findsOneWidget, reason: '${entry.key} sheet dark=$dark');
                expect(tester.takeException(), isNull, reason: '${entry.key} sheet dark=$dark');
                await tester.binding.handlePopRoute(); // close it again
                await tester.pumpAndSettle();
              }
            }
          }
        }

        // every font at the largest text size, in every mode
        for (final font in FontChoice.values) {
          for (final mode in ['today', 'other day']) {
            SharedPreferences.setMockInitialValues({'city': 'dragash', 'font': font.name, 'fontScale': 1.25});
            final controller = AppController(
              prefs: await SharedPreferences.getInstance(),
              clock: () => instants['forbidden']!.millisecondsSinceEpoch,
            );
            if (mode == 'other day') controller.select(controller.today.addDays(1));
            await tester.pumpWidget(VaktetApp(controller: controller, skyMotion: false));
            await tester.pump(const Duration(milliseconds: 50));
            expect(tester.takeException(), isNull, reason: '${font.name} ×1.25 $mode');
          }
        }

        // the month tab and the settings
        SharedPreferences.setMockInitialValues({'city': 'dragash'});
        final controller = AppController(
          prefs: await SharedPreferences.getInstance(),
          clock: () => instants['dusk']!.millisecondsSinceEpoch,
        );
        await tester.pumpWidget(VaktetApp(controller: controller, skyMotion: false));
        controller.setView(HomeView.month);
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull, reason: 'month');
        controller.select(controller.today.addDays(3));
        controller.setView(HomeView.today);
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull, reason: 'another day');
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Cilësimet'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'settings');
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
    }
  }
}
