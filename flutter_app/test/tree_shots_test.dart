import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaktet/src/logic/cities.dart';
import 'package:vaktet/src/logic/day.dart';
import 'package:vaktet/src/logic/prayer.dart';
import 'package:vaktet/src/logic/sky_scene.dart';
import 'package:vaktet/src/ui/sky.dart';

void main() {
  test('tree through the year', () async {
    const size = Size(390, 844);
    final shots = <(Day, double)>[
      (const Day(2026, 4, 10), 10.0),
      (const Day(2026, 8, 28), 17.0),
      (const Day(2026, 11, 2), 14.0),
      (const Day(2026, 1, 20), 12.5),
      (const Day(2026, 1, 20), 21.0),
    ];
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    for (var i = 0; i < shots.length; i++) {
      final (day, hour) = shots[i];
      final rows = dayRows(day, cityById(null));
      final now = rows.first.instant - rows.first.local * 60000 + (hour * 3600000).round();
      final scene = skySceneAt(rows, now, day);
      canvas.save();
      canvas.translate(i * 230.0, -480);
      canvas.clipRect(const Rect.fromLTWH(0, 480, 230, 364));
      for (final layer in [SkyLayer.back, SkyLayer.land]) {
        SkyPainter(layer: layer, phase: skyPhase(rows, now), orb: orbAt(rows, now), scene: scene, forbidden: false,
            mode: SkyMode.full, dark: false, radius: 0).paint(canvas, size);
      }
      canvas.restore();
    }
    final img = rec.endRecording().toImageSync(230 * shots.length, 364);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/shots').createSync(recursive: true);
    File('build/shots/tree.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}
