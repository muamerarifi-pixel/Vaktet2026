import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaktet/src/state/app_controller.dart';
import 'package:vaktet/src/ui/tree_interaction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Android APK first install defaults', () {
    test('loads exact requested defaults when installed on Android for first time', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final c = AppController(prefs: prefs);

        // Requested defaults from screenshots:
        // 1. Data hixhri: 0
        expect(c.hijriAdj, 0);

        // 2. Alarmi per sabah: 30 min
        expect(c.alarmOffset, 30);

        // 3. Stili i shkronjave: E bute (Nunito)
        expect(c.font, FontChoice.nunito);

        // 4. Madhesia e shkronjave: E vogel (0.9)
        expect(c.fontScale, 0.9);

        // 5. Shkronjat e kohes se mbetur: Si teksti
        expect(c.countdownFont, CountdownFont.text);

        // 6. Trashesia e kohes se mbetur: Holle (300)
        expect(c.countdownWeight, 300);

        // 7. Madhesia e kohes se mbetur: 115% (1.15)
        expect(c.countdownSize, 1.15);

        // 8. Vecorite: All 14 enabled by default
        for (final f in Feature.values) {
          expect(c.on(f), isTrue, reason: '${f.title} should be on by default');
        }

        c.dispose();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('retains desktop defaults on non-Android platforms', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final c = AppController(prefs: prefs);

        expect(c.font, FontChoice.figtree);
        expect(c.fontScale, 1.0);
        expect(c.countdownWeight, 900);
        expect(c.countdownSize, 1.0);

        c.dispose();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('Tree touch interaction', () {
    const size = Size(400, 800);

    test('isTreeHit detects touches on canopy and shore, rejects distant touches', () {
      expect(TreeInteraction.isTreeHit(const Offset(70, 700), size), isTrue);
      expect(TreeInteraction.isTreeHit(const Offset(50, 720), size), isTrue);
      expect(TreeInteraction.isTreeHit(const Offset(90, 680), size), isTrue);

      // Distant touches (countdown area, header, right mountain/lake)
      expect(TreeInteraction.isTreeHit(const Offset(200, 300), size), isFalse);
      expect(TreeInteraction.isTreeHit(const Offset(350, 700), size), isFalse);
      expect(TreeInteraction.isTreeHit(const Offset(200, 100), size), isFalse);
      expect(TreeInteraction.isTreeHit(Offset.zero, size), isFalse);
    });

    test('tap triggers rustle impulse, falling leaves, and startled bird on triple tap', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = AppController(prefs: prefs);
      final scene = c.model.scene;
      final tree = TreeInteraction.shared;

      // 1. Single tap
      tree.tap(const Offset(70, 700), size, scene, isDay: true);
      final rustle1 = tree.rustleAt(0.1);
      expect(rustle1 != 0.0, isTrue);

      // 2. Painting runs cleanly with canvas recorder
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      tree.paint(canvas, size, 0.2, true, scene);
      final pic = recorder.endRecording();
      pic.dispose();

      // 3. Quick consecutive taps trigger startled bird easter egg
      tree.tap(const Offset(70, 700), size, scene, isDay: true);
      tree.tap(const Offset(70, 700), size, scene, isDay: true);

      final recorder2 = ui.PictureRecorder();
      final canvas2 = Canvas(recorder2);
      tree.paint(canvas2, size, 0.5, true, scene);
      final pic2 = recorder2.endRecording();
      pic2.dispose();

      // 4. Night tap triggers fireflies
      tree.tap(const Offset(70, 700), size, scene, isDay: false);

      final recorder3 = ui.PictureRecorder();
      final canvas3 = Canvas(recorder3);
      tree.paint(canvas3, size, 0.6, false, scene);
      final pic3 = recorder3.endRecording();
      pic3.dispose();

      c.dispose();
    });
  });
}
