import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaktet/src/logic/prayer.dart';
import 'package:vaktet/src/ui/touch_ripples.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TouchRipples stress-relief sky rings', () {
    const size = Size(400, 800);

    tearDown(() {
      TouchRipples.shared.clear();
    });

    test('quick tap spawns concentric sky-rings and paints cleanly across phases', () {
      final ripples = TouchRipples.shared;
      expect(ripples.hasActive, isFalse);

      ripples.pointerDown(1, const Offset(200, 320), haptics: false);
      expect(ripples.hasActive, isTrue);
      ripples.pointerUp(1);
      expect(ripples.activeRippleCount, 1);

      for (final phase in SkyPhase.values) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        ripples.paint(canvas, size, 0.35, phase, dark: true);
        final pic = recorder.endRecording();
        pic.dispose();
      }
    });

    test('calm hold-to-breathe activates after 240ms and releases into a deep wave', () async {
      final ripples = TouchRipples.shared;

      ripples.pointerDown(2, const Offset(180, 400), haptics: false);
      expect(ripples.isHoldingBreath, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 280));
      expect(ripples.isHoldingBreath, isTrue);

      // Paint active breathing halo
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      ripples.paint(canvas, size, 1.2, SkyPhase.night, dark: true);
      final pic = recorder.endRecording();
      pic.dispose();

      // Release into deep wave
      ripples.pointerUp(2);
      expect(ripples.isHoldingBreath, isFalse);
      expect(ripples.activeRippleCount, 1);
    });

    test('vertical swipe cancels hold cleanly without spawning a false ripple', () {
      final ripples = TouchRipples.shared;

      ripples.pointerDown(3, const Offset(200, 600), haptics: false);
      ripples.pointerMove(3, const Offset(200, 560)); // 40px swipe > 18px threshold
      ripples.pointerUp(3);

      expect(ripples.isHoldingBreath, isFalse);
      expect(ripples.activeRippleCount, 0);
    });
  });
}
