// Preview only (not committed): the land at a few moments of the year, side by side.
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
  test('preview', () async {
    Directory('build').createSync(recursive: true);
    const size = Size(378, 770);
    final shots = <(Day, double)>[
      (const Day(2026, 10, 17), 16.0),
      (const Day(2026, 7, 10), 11.0),
      (const Day(2026, 4, 20), 18.5),
      (const Day(2026, 1, 15), 13.0),
      (const Day(2026, 10, 17), 22.0),
    ];
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    for (var i = 0; i < shots.length; i++) {
      final (day, hour) = shots[i];
      final rows = dayRows(day, cityById(null));
      final base = rows.first.instant - rows.first.local * 60000;
      final now = base + (hour * 3600000).round();
      final scene = skySceneAt(rows, now, day);
      canvas.save();
      canvas.translate(i * size.width, -360);
      canvas.clipRect(Offset.zero & size);
      for (final layer in [SkyLayer.back, SkyLayer.land]) {
        SkyPainter(
          layer: layer,
          phase: skyPhase(rows, now),
          orb: orbAt(rows, now),
          scene: scene,
          forbidden: false,
          mode: SkyMode.full,
          dark: false,
          radius: 0,
        ).paint(canvas, size);
      }
      canvas.restore();
    }
    final img = rec.endRecording().toImageSync((size.width * shots.length).round(), 410);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('build/preview.png')
        .writeAsBytesSync(png!.buffer.asUint8List());
  });
}
