import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaktet/src/app.dart';
import 'package:vaktet/src/logic/cities.dart';
import 'package:vaktet/src/logic/day.dart';
import 'package:vaktet/src/logic/prayer.dart';
import 'package:vaktet/src/state/app_controller.dart';

// Temporary: pictures of the prayer status above the countdown (not part of the app's tests).
void main() {
  testWidgets('status shots', (tester) async {
    await tester.runAsync(() async {
      for (final f in ['Figtree', 'Manrope-Light', 'Nunito', 'Lora']) {
        final family = f.split('-').first;
        final loader = FontLoader(family)..addFont(Future.value(ByteData.view(File('assets/fonts/$f.ttf').readAsBytesSync().buffer)));
        await loader.load();
      }
    });
    const day = Day(2026, 10, 26);
    final rows = dayRows(day, cityById('kosove'));
    final m = rowOf(rows, PrayerKey.maghrib).instant;
    final i = rowOf(rows, PrayerKey.isha).instant;
    final times = [m + 5 * msPerMinute, m + 40 * msPerMinute, i - 18 * msPerMinute, i - 3 * msPerMinute];
    final images = <ui.Image>[];
    for (final t in times) {
      SharedPreferences.setMockInitialValues({});
      final store = await SharedPreferences.getInstance();
      final c = AppController(prefs: store, clock: () => t);
      tester.view.physicalSize = const Size(390, 844) * 2;
      tester.view.devicePixelRatio = 2;
      await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: VaktetApp(controller: c, skyMotion: false)));
      await tester.pump(const Duration(milliseconds: 800));
      final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
      final img = await tester.runAsync(() => ro.toImage(pixelRatio: 1));
      images.add(img!);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    }
    final bytes = await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      for (var k = 0; k < images.length; k++) {
        canvas.drawImage(images[k], Offset(k * 390.0, 0), Paint());
      }
      final im = await rec.endRecording().toImage(390 * images.length, 844);
      return im.toByteData(format: ui.ImageByteFormat.png);
    });
    Directory('build/shots').createSync(recursive: true);
    File('build/shots/status.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
