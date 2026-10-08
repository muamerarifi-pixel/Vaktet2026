import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../logic/prayer.dart';
import 'colors.dart';

/// The land under the full-screen sky: snowy mountains, a hill with a mosque, a village with its houses and trees,
/// a lake that mirrors the sky and a meadow in front. Everything takes its light from the sky above it: the hour,
/// the sunrise and sunset, the moon, the season and the snow.
///
/// Laid out in a box at the bottom of the screen: x from 0 to 400 across the width, v from 0 (the top of the box)
/// to 100 (the bottom of the screen); the mountains rise above the box.
class Landscape {
  Landscape({
    required this.size,
    required this.pal,
    required this.scene,
    required this.dim,
    required this.mosque,
    required this.village,
    required this.friday,
    required this.festive,
  });

  final Size size;
  final SkyPalette pal;
  final SkyScene scene;

  /// The dark theme's dimming of a colour.
  final Color Function(Color) dim;

  /// Draw the mosque on the hill.
  final bool mosque;

  /// Draw the village, the lake and the meadow (otherwise only the mountains and the hill).
  final bool village;

  /// The day shown is a Friday.
  final bool friday;

  /// A great night or day, or Ramazan: the minaret is hung with lights after dark.
  final bool festive;

  double get w => size.width;
  double get h => size.height;

  /// Height of the box.
  static double heightFor(Size size) => math.min(.27 * size.height, 236.0);

  late final double boxH = heightFor(size);
  double get top => h - boxH;

  /// One unit of the box, the same across and up (for buildings, which must not stretch).
  double get u => boxH / 100;
  double x(double X) => X / 400 * w;
  double y(double v) => top + v * boxH / 100;

  /// Where the sun and the moon go down: behind the mountains.
  static double horizonFor(Size size) => size.height - heightFor(size) * 1.06;

  // ---------- Light ----------

  /// The light of the moon on the land at night (a full moon lights it up softly).
  late final double moonlight = scene.moon.up ? .22 * scene.moon.illumination * (1 - daylight) : 0;

  /// 1 in full daylight, about .1 in the depth of the night.
  late final double daylight = (1 - pal.stars * .9).clamp(0.0, 1.0);

  /// How strongly the low sun colours everything orange and pink (around sunrise and sunset).
  late final double warm = () {
    final sp = scene.sunProgress;
    final edge = math.min((sp - 0).abs(), (sp - 1).abs());
    return _smooth(1 - edge / .2);
  }();

  /// Where the sun is across the screen (0–1), for the side the light comes from.
  late final double sunX = .5 - .42 * math.cos(math.pi * scene.sunProgress.clamp(0.0, 1.0));

  late final Color _haze = pal.colors.last;
  late final Color _sky = pal.colors[pal.colors.length ~/ 2];
  static const Color _night = Color(0xFF0A1030);
  late final Color _sunLight = Color.lerp(pal.sun, const Color(0xFFFF8A5C), .55)!;

  /// The colour of a surface of colour [albedo], [depth] away (0 near, 1 far, in the haze), lit by the sky.
  /// [facing] is how much it faces the sun (−1 away, 1 towards it).
  Color lit(Color albedo, {double depth = 0, double facing = 0}) {
    final light = .17 + moonlight + .83 * daylight * (1 + .18 * facing);
    var c = Color.from(
      alpha: 1,
      red: (albedo.r * light).clamp(0.0, 1.0),
      green: (albedo.g * light).clamp(0.0, 1.0),
      blue: (albedo.b * light).clamp(0.0, 1.0),
    );
    // night is blue
    c = Color.lerp(c, _night, (1 - daylight) * .45)!;
    // the low sun warms what faces it
    if (warm > 0) {
      final glow = Color.from(
        alpha: 1,
        red: (albedo.r * _sunLight.r * 1.15).clamp(0.0, 1.0),
        green: (albedo.g * _sunLight.g * 1.1).clamp(0.0, 1.0),
        blue: (albedo.b * _sunLight.b).clamp(0.0, 1.0),
      );
      c = Color.lerp(c, glow, warm * daylight * (.28 + .22 * facing.clamp(0.0, 1.0)))!;
    }
    // the colour of the hour
    if (scene.tintStrength > 0) c = Color.lerp(c, Color(scene.tint), scene.tintStrength * .5)!;
    // far away things fade into the sky
    if (depth > 0) c = Color.lerp(c, _haze, depth * (.32 + .38 * daylight))!;
    return dim(c);
  }

  /// Snow lying on the ground (the hills of winter).
  double get snow => scene.snow;

  /// Snow on the high mountains: most of the year, but only on the peaks in summer.
  double get peakSnow => math.max(scene.snow, .1 + .7 * math.pow(_coldness, 1.3));

  /// 1 in mid-January, 0 in mid-July.
  double get _coldness => scene.cold;

  /// Grass through the seasons, and the season's colour of the leaves.
  late final Color grass = () {
    final season = Color(scene.season);
    final g = Color.lerp(season, const Color(0xFF3C7A34), .38)!;
    return Color.lerp(g, const Color(0xFFE9EFF5), snow * .92)!;
  }();

  late final Color leaves = () {
    final season = Color(scene.season);
    return Color.lerp(season, const Color(0xFF2E6A33), .3)!;
  }();

  /// The leaves have fallen (winter).
  bool get bare => snow > .5;

  // ---------- Shapes ----------

  /// A smooth line through [pts] (x, v), closed down to the bottom of the screen.
  Path _ridge(List<(double, double)> pts, {double bottom = 104}) {
    final p = Path()..moveTo(x(pts.first.$1), y(pts.first.$2));
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[math.max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[math.min(pts.length - 1, i + 2)];
      p.cubicTo(
        x(p1.$1 + (p2.$1 - p0.$1) / 6),
        y(p1.$2 + (p2.$2 - p0.$2) / 6),
        x(p2.$1 - (p3.$1 - p1.$1) / 6),
        y(p2.$2 - (p3.$2 - p1.$2) / 6),
        x(p2.$1),
        y(p2.$2),
      );
    }
    return p
      ..lineTo(x(pts.last.$1), y(bottom))
      ..lineTo(x(pts.first.$1), y(bottom))
      ..close();
  }

  /// The height (v) of a smooth line at [X].
  static double _heightAt(List<(double, double)> pts, double X) {
    for (var i = 0; i < pts.length - 1; i++) {
      final (x0, v0) = pts[i];
      final (x1, v1) = pts[i + 1];
      if (X >= x0 && X <= x1) {
        final t = (X - x0) / (x1 - x0);
        return v0 + (v1 - v0) * (t * t * (3 - 2 * t));
      }
    }
    return pts.last.$2;
  }

  static const List<(double, double)> _farPeaks = [
    (-10, 6),
    (8, -2),
    (22, 2),
    (40, -14),
    (52, -8),
    (64, -22),
    (76, -12),
    (88, -6),
    (102, -18),
    (118, -34),
    (130, -24),
    (140, -28),
    (154, -12),
    (170, -4),
    (186, 2),
    (204, -6),
    (220, 0),
    (238, 4),
    (262, -4),
    (284, 2),
    (300, -10),
    (318, -20),
    (332, -30),
    (346, -22),
    (358, -26),
    (372, -12),
    (388, -16),
    (410, -2),
  ];

  static const List<(double, double)> _nearPeaks = [
    (-10, 18),
    (14, 10),
    (36, 16),
    (58, 6),
    (80, 14),
    (102, 12),
    (126, 20),
    (150, 14),
    (176, 22),
    (206, 18),
    (236, 24),
    (270, 20),
    (300, 14),
    (326, 8),
    (352, 16),
    (378, 10),
    (410, 18),
  ];

  /// The hill of the mosque.
  static const List<(double, double)> _hill = [
    (-10, 40),
    (30, 36),
    (70, 38),
    (110, 34),
    (150, 36),
    (190, 31),
    (230, 27),
    (262, 26),
    (296, 29),
    (330, 34),
    (370, 31),
    (410, 35),
  ];

  /// The village slope in front of it.
  static const List<(double, double)> _slope = [
    (-10, 46),
    (24, 43),
    (60, 45),
    (96, 47),
    (130, 50),
    (170, 52),
    (220, 53),
    (270, 51),
    (306, 48),
    (340, 45),
    (376, 43),
    (410, 46),
  ];

  static const double _shoreV = 59;
  static const double _meadowV = 80;

  /// x (0–400) of the mosque.
  static const double mosqueX = 262;

  // ---------- Painting ----------

  /// Everything that does not move.
  void paintStill(Canvas canvas) {
    _mountains(canvas);
    _hillAndMosque(canvas);
    if (village) {
      _villageSlope(canvas);
      _lake(canvas);
      _meadow(canvas);
    }
  }

  void _mountains(Canvas canvas) {
    // the far range: pale with distance, rocky faces lit from the sun's side, snow on the peaks
    _range(canvas, _farPeaks, const Color(0xFF7D879B), depth: .62, snowLine: _lerp(-26, 30, peakSnow), base: 44);
    // the nearer range: darker, wooded
    _range(
      canvas,
      _nearPeaks,
      Color.lerp(const Color(0xFF3E5A48), Color(scene.season), .18)!,
      depth: .34,
      snowLine: _lerp(4, 40, snow),
      base: 50,
    );
  }

  void _range(
    Canvas canvas,
    List<(double, double)> peaks,
    Color rock, {
    required double depth,
    required double snowLine,
    required double base,
  }) {
    final outline = Path()..moveTo(x(peaks.first.$1), y(peaks.first.$2));
    for (final (X, v) in peaks.skip(1)) {
      outline.lineTo(x(X), y(v));
    }
    outline
      ..lineTo(x(peaks.last.$1), y(104))
      ..lineTo(x(peaks.first.$1), y(104))
      ..close();
    canvas.drawPath(outline, Paint()..color = lit(rock, depth: depth));

    // snow above the snow line, with a ragged lower edge
    if (snowLine > -40) {
      final snowColor = lit(const Color(0xFFF4F7FB), depth: depth * .8, facing: .3);
      // alpenglow: the snow turns pink at sunrise and sunset
      final tinted = Color.lerp(snowColor, dim(const Color(0xFFFFB8A8)), warm * daylight * .45)!;
      final rnd = math.Random(peaks.length);
      final cap = Path()..moveTo(x(-12), y(-60));
      for (var X = -12.0; X <= 412; X += 5) {
        cap.lineTo(x(X), y(snowLine + (rnd.nextDouble() - .5) * 7 + 2.5 * math.sin(X * .11)));
      }
      cap
        ..lineTo(x(412), y(-60))
        ..close();
      canvas.save();
      canvas.clipPath(outline);
      canvas.drawPath(cap, Paint()..color = tinted.withValues(alpha: .9));
      canvas.restore();
    }
    // depth: lighter at the top of the range, darker at its foot
    canvas.drawPath(
      outline,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, y(-34)), Offset(0, y(base + 6)), [
          Colors.white.withValues(alpha: .06 * daylight),
          Colors.black.withValues(alpha: .10 + .06 * daylight),
        ]),
    );
    // the faces: from each peak a ridge runs down to the foot; the side away from the sun is in shade
    canvas.save();
    canvas.clipPath(outline);
    final shadeLeft = sunX >= .5; // the sun in the west: the east (left) faces are in shade
    final shade = Paint()..color = Colors.black.withValues(alpha: .07 + .16 * daylight + .05 * warm);
    final light = Paint()..color = Colors.white.withValues(alpha: .05 * daylight + .06 * warm * daylight);
    for (var i = 1; i < peaks.length - 1; i++) {
      final (px, pv) = peaks[i];
      if (!(pv < peaks[i - 1].$2 && pv < peaks[i + 1].$2)) continue; // only the peaks
      // down to the valley on each side
      var l = i, r = i;
      while (l > 0 && peaks[l - 1].$2 > peaks[l].$2) {
        l--;
      }
      while (r < peaks.length - 1 && peaks[r + 1].$2 > peaks[r].$2) {
        r++;
      }
      final foot = Offset(x(px + (shadeLeft ? -4 : 4)), y(base + 4));
      Path side(int to) {
        final path = Path()..moveTo(x(px), y(pv));
        final step = to > i ? 1 : -1;
        for (var k = i + step; step > 0 ? k <= to : k >= to; k += step) {
          path.lineTo(x(peaks[k].$1), y(peaks[k].$2));
        }
        return path
          ..lineTo(x(peaks[to].$1), y(base + 4))
          ..lineTo(foot.dx, foot.dy)
          ..close();
      }

      canvas.drawPath(side(shadeLeft ? l : r), shade);
      canvas.drawPath(side(shadeLeft ? r : l), light);
    }
    canvas.restore();

    // a little haze at the foot of the range
    canvas.drawRect(
      Rect.fromLTRB(0, y(base - 30), w, y(base + 6)),
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, y(base - 30)), Offset(0, y(base + 6)), [
          dim(_haze).withValues(alpha: 0),
          dim(_haze).withValues(alpha: .18 + .14 * scene.mist),
        ]),
    );
  }

  void _hillAndMosque(Canvas canvas) {
    final hillColor = Color.lerp(const Color(0xFF2F5C3A), Color(scene.season), .42)!;
    final snowy = Color.lerp(hillColor, const Color(0xFFE6ECF2), snow * .85)!;
    final hill = _ridge(_hill);
    canvas.drawPath(
      hill,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, y(24)), Offset(0, y(60)), [
          lit(snowy, depth: .2, facing: .2),
          lit(snowy, depth: .1),
        ]),
    );
    // woods along the hill: an uneven line of tree tops (grey and bare in winter), open around the mosque
    final woodColor = bare
        ? Color.lerp(const Color(0xFF6E625A), const Color(0xFFE6ECF2), .35 * snow)!
        : Color.lerp(leaves, Colors.black, .3)!;
    final wood = Path()..moveTo(x(-10), y(_heightAt(_hill, -10) + 6));
    final rnd = math.Random(4);
    for (var X = -10.0; X <= 410; X += 3) {
      final open = (X - mosqueX).abs() < 30;
      final ground = _heightAt(_hill, X) + 1.5;
      final crown = open ? 0.0 : (1.4 + rnd.nextDouble() * 2.2) * (.7 + .3 * math.sin(X * .05).abs());
      final p = Offset(x(X), y(ground - crown));
      // a round tree top between each step
      wood.quadraticBezierTo(x(X - 1.5), p.dy - crown * .6 * u, p.dx, p.dy);
    }
    wood
      ..lineTo(x(410), y(_heightAt(_hill, 410) + 6))
      ..close();
    canvas.drawPath(wood, Paint()..color = lit(woodColor, depth: .18).withValues(alpha: bare ? .75 : 1));
    if (mosque) {
      _mosque(canvas, Offset(x(mosqueX), y(_heightAt(_hill, mosqueX)) + .6 * u), u);
    }
  }

  /// A mosque in the Ottoman style of Kosovo: a prayer hall under one great dome, two half domes, a portico and a
  /// tall pencil minaret, all in pale stone with lead roofs and golden crescents.
  void mosqueAt(Canvas canvas, Offset base, double unit) => _mosque(canvas, base, unit);

  void _mosque(Canvas canvas, Offset base, double unit) {
    final s = unit;
    final mx = base.dx, by = base.dy;
    final stone = lit(const Color(0xFFEDE5D6), depth: .16, facing: (sunX - .5) * 2);
    final stoneShade = lit(const Color(0xFFD6CBB8), depth: .16, facing: (.5 - sunX) * 2);
    final lead = lit(const Color(0xFF8C98A8), depth: .16, facing: .2);
    final night = 1 - daylight;
    final gold = dim(Color.lerp(const Color(0xFFC99A3A), const Color(0xFFFFD77A), .5 + .5 * daylight)!);

    // the glow of the floodlights at night
    if (night > .3) {
      final glowR = 34 * s;
      final c = Offset(mx, by - 10 * s);
      final glow = dim(friday ? const Color(0xFFFFD88A) : const Color(0xFFFFE6B8));
      canvas.drawCircle(
        c,
        glowR,
        Paint()
          ..shader = ui.Gradient.radial(c, glowR, [
            glow.withValues(alpha: (friday ? .22 : .14) * (night - .3) / .7),
            glow.withValues(alpha: 0),
          ]),
      );
    }

    final p = Paint();
    // the prayer hall
    final hall = Rect.fromLTRB(mx - 13 * s, by - 9 * s, mx + 13 * s, by);
    p.color = stone;
    canvas.drawRect(hall, p);
    // the shaded side
    p.color = stoneShade;
    canvas.drawRect(
      sunX < .5
          ? Rect.fromLTRB(mx + 4 * s, hall.top, hall.right, by)
          : Rect.fromLTRB(hall.left, hall.top, mx - 4 * s, by),
      p,
    );
    // the portico in front: three little domes on arches
    final porch = Rect.fromLTRB(mx - 15 * s, by - 4.6 * s, mx + 15 * s, by);
    p.color = stone;
    canvas.drawRect(porch, p);
    p.color = lead;
    for (final dx in [-10.0, 0.0, 10.0]) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(mx + dx * s, porch.top), radius: 2.6 * s),
        math.pi,
        math.pi,
        true,
        p,
      );
    }
    // the arches of the portico (dark, or lit from inside at night)
    final arch = Paint()
      ..color = night > .4
          ? dim(const Color(0xFFFFD27A)).withValues(alpha: .55 + .3 * night)
          : lit(const Color(0xFF4A4038), depth: .16);
    for (final dx in [-12.0, -7.5, -2.5, 2.5, 7.5, 12.0]) {
      final r = Rect.fromLTWH(mx + dx * s - .9 * s, by - 3.4 * s, 1.8 * s, 3.4 * s);
      canvas.drawRRect(
        RRect.fromRectAndCorners(r, topLeft: Radius.circular(.9 * s), topRight: Radius.circular(.9 * s)),
        arch,
      );
    }
    // the half domes
    p.color = lead;
    for (final dx in [-9.0, 9.0]) {
      canvas.drawArc(Rect.fromCircle(center: Offset(mx + dx * s, hall.top), radius: 4 * s), math.pi, math.pi, true, p);
    }
    // the drum with its row of little windows
    final drum = Rect.fromLTRB(mx - 7.6 * s, hall.top - 3 * s, mx + 7.6 * s, hall.top);
    p.color = stone;
    canvas.drawRect(drum, p);
    final windowLight = night > .35
        ? dim(const Color(0xFFFFD98E)).withValues(alpha: .6 + .4 * night)
        : lit(const Color(0xFF3B3631), depth: .16);
    final win = Paint()..color = windowLight;
    for (var i = -3; i <= 3; i++) {
      canvas.drawRect(
        Rect.fromCenter(center: Offset(mx + i * 2 * s, drum.center.dy), width: .7 * s, height: 1.6 * s),
        win,
      );
    }
    // the windows of the hall
    for (final dx in [-9.0, -4.5, 4.5, 9.0]) {
      final r = Rect.fromLTWH(mx + dx * s - .7 * s, hall.top + 1.4 * s, 1.4 * s, 2.6 * s);
      canvas.drawRRect(
        RRect.fromRectAndCorners(r, topLeft: Radius.circular(.7 * s), topRight: Radius.circular(.7 * s)),
        win,
      );
    }

    // the great dome, lit on the sun's side; snow on it in winter
    final domeC = Offset(mx, drum.top);
    final domeR = 7.8 * s;
    final dome = Path()..addArc(Rect.fromCircle(center: domeC, radius: domeR), math.pi, math.pi);
    final light = Offset(mx + (sunX - .5) * 2 * domeR * .8, drum.top - domeR * .7);
    canvas.drawPath(
      dome,
      Paint()
        ..shader = ui.Gradient.radial(
          light,
          domeR * 1.6,
          [
            Color.lerp(lead, Colors.white, .25 * daylight + .2 * warm * daylight)!,
            lead,
            Color.lerp(lead, Colors.black, .25)!,
          ],
          const [0, .55, 1],
        ),
    );
    if (warm * daylight > .05) {
      // the low sun catches the rim of the dome
      canvas.drawPath(
        dome,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7 * s
          ..color = dim(_sunLight).withValues(alpha: .5 * warm * daylight),
      );
    }
    if (snow > .05) {
      canvas.save();
      canvas.clipPath(dome);
      canvas.drawRect(
        Rect.fromLTRB(domeC.dx - domeR, domeC.dy - domeR, domeC.dx + domeR, domeC.dy - domeR * .35),
        Paint()..color = lit(const Color(0xFFF4F7FB), depth: .1).withValues(alpha: .9 * snow),
      );
      canvas.restore();
    }
    _crescent(canvas, Offset(mx, domeC.dy - domeR), 2.6 * s, gold, s);

    // the minaret
    final mxR = mx + 18 * s;
    final shaftW = 2.3 * s;
    p.color = stone;
    canvas.drawRect(Rect.fromLTRB(mxR - 1.9 * s, by - 7 * s, mxR + 1.9 * s, by), p); // the base
    final shaft = Rect.fromLTRB(mxR - shaftW / 2, by - 35 * s, mxR + shaftW / 2, by - 7 * s);
    canvas.drawRect(shaft, p);
    p.color = stoneShade;
    canvas.drawRect(
      sunX < .5
          ? Rect.fromLTRB(mxR + shaftW * .1, shaft.top, shaft.right, shaft.bottom)
          : Rect.fromLTRB(shaft.left, shaft.top, mxR - shaftW * .1, shaft.bottom),
      p,
    );
    // the balcony (şerefe)
    final balconyY = by - 27 * s;
    p.color = stone;
    canvas.drawRect(Rect.fromLTRB(mxR - 2.2 * s, balconyY - .5 * s, mxR + 2.2 * s, balconyY + 1 * s), p);
    p.color = stoneShade;
    canvas.drawRect(Rect.fromLTRB(mxR - 2.2 * s, balconyY + .6 * s, mxR + 2.2 * s, balconyY + 1 * s), p);
    // the pencil cap
    final cap = Path()
      ..moveTo(mxR - shaftW / 2 - .2 * s, shaft.top)
      ..lineTo(mxR, shaft.top - 9 * s)
      ..lineTo(mxR + shaftW / 2 + .2 * s, shaft.top)
      ..close();
    p.color = lead;
    canvas.drawPath(cap, p);
    if (snow > .3) {
      canvas.drawPath(
        Path()
          ..moveTo(mxR - .8 * s, shaft.top - 5.6 * s)
          ..lineTo(mxR, shaft.top - 9 * s)
          ..lineTo(mxR + .8 * s, shaft.top - 5.6 * s)
          ..close(),
        Paint()..color = lit(const Color(0xFFF4F7FB)).withValues(alpha: .85 * snow),
      );
    }
    _crescent(canvas, Offset(mxR, shaft.top - 9 * s), 2 * s, gold, s);

    // after dark: the balcony is lit, and on Fridays and great nights the minaret is hung with lights (mahya)
    if (night > .35) {
      final a = (night - .35) / .65;
      final bulb = dim(const Color(0xFFFFE3A0));
      final dot = Paint()..color = bulb.withValues(alpha: .95 * a);
      final halo = Paint()..color = bulb.withValues(alpha: .25 * a);
      for (var i = -2; i <= 2; i++) {
        final c = Offset(mxR + i * .9 * s, balconyY - .1 * s);
        canvas.drawCircle(c, .9 * s, halo);
        canvas.drawCircle(c, .32 * s, dot);
      }
      if (friday || festive) {
        // a string of lights from the balcony to the dome's crescent, and on to the hall's corner
        final from = Offset(mxR - 2.2 * s, balconyY);
        final to = Offset(mx + 1.5 * s, domeC.dy - domeR - 1 * s);
        final end = Offset(mx - 14 * s, hall.top + .5 * s);
        for (final (a0, b0, sag) in [(from, to, 4.0), (to, end, 5.0)]) {
          const n = 12;
          for (var i = 0; i <= n; i++) {
            final t = i / n;
            final c = Offset.lerp(a0, b0, t)! + Offset(0, sag * s * math.sin(math.pi * t));
            canvas.drawCircle(c, .8 * s, halo);
            canvas.drawCircle(c, .28 * s, dot);
          }
        }
      }
    }
  }

  void _crescent(Canvas canvas, Offset tip, double height, Color gold, double s) {
    final pole = Paint()
      ..color = gold
      ..strokeWidth = .35 * s
      ..strokeCap = StrokeCap.round;
    final c = tip.translate(0, -height * .75);
    canvas.drawLine(tip, tip.translate(0, -height * .45), pole);
    final r = height * .32;
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: c, radius: r)),
      Path()..addOval(Rect.fromCircle(center: c.translate(r * .45, -r * .2), radius: r * .82)),
    );
    canvas.drawPath(moon, Paint()..color = gold);
  }

  /// Houses on the slope: (x, kind, seed). Kind 0 a house, 1 a two-storey house, 2 a stone tower house (kulla).
  static const List<(double, int, double)> _houses = [
    (18, 0, .2),
    (34, 1, .7),
    (52, 0, .4),
    (70, 2, .9),
    (88, 0, .1),
    (112, 1, .5),
    (138, 0, .8),
    (300, 0, .3),
    (318, 1, .6),
    (336, 0, .15),
    (352, 2, .45),
    (370, 0, .75),
    (390, 1, .35),
  ];

  /// Trees on the slope and by the lake: (x, v, kind, size). Kind 0 a round tree, 1 a poplar.
  static const List<(double, double, int, double)> _trees = [
    (8, 46, 1, 1.0),
    (26, 47, 0, .9),
    (44, 49, 1, 1.1),
    (61, 51, 0, 1.0),
    (80, 50, 1, .9),
    (100, 52, 0, 1.1),
    (124, 54, 1, 1.0),
    (150, 55, 0, 1.2),
    (176, 57, 0, .9),
    (196, 56, 1, 1.1),
    (226, 57, 0, 1.0),
    (250, 56, 1, .95),
    (282, 54, 0, 1.0),
    (310, 52, 1, 1.0),
    (328, 49, 0, .8),
    (344, 50, 1, 1.05),
    (362, 47, 0, .9),
    (382, 48, 1, 1.0),
  ];

  /// Where a house stands: on the slope, some higher up and some further down.
  Offset _houseBase(double X, double seed) => Offset(x(X), y(_heightAt(_slope, X) + 1 + (seed * 13 % 1) * 5.5));

  /// The size of a house: (width, height of the walls).
  (double, double) _houseSize(int kind, double seed) =>
      ((kind == 2 ? 5.6 : 6.8 + seed * 1.6) * u, (kind == 0 ? 4.2 : (kind == 1 ? 6.6 : 8.4)) * u);

  /// Where the windows of the village are, for the lights and their reflections: (centre, order they go out).
  List<(Offset, double)> windows() {
    final out = <(Offset, double)>[];
    for (final (X, kind, seed) in _houses) {
      final b = _houseBase(X, seed);
      final (_, wallH) = _houseSize(kind, seed);
      out.add((b.translate(-1.1 * u, -wallH * .5), seed));
      if (kind != 0) out.add((b.translate(1.2 * u, -wallH * .75), (seed + .37) % 1));
    }
    return out;
  }

  void _villageSlope(Canvas canvas) {
    final slope = _ridge(_slope);
    final ground = Color.lerp(grass, Colors.black, .12)!;
    canvas.drawPath(
      slope,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, y(42)), Offset(0, y(_shoreV)), [
          lit(ground, depth: .08, facing: .1),
          lit(Color.lerp(ground, Colors.black, .2)!, depth: .02),
        ]),
    );
    // fields: a few long strips across the slope, a shade lighter or darker
    final field = Paint();
    for (var i = 0; i < 4; i++) {
      final fx = 150.0 + i * 22, v0 = _heightAt(_slope, fx) + 2 + i * 1.6;
      field.color = (i.isEven ? Colors.white : Colors.black).withValues(alpha: .05 * daylight);
      canvas.drawPath(
        Path()
          ..moveTo(x(fx - 40), y(v0 + 1))
          ..quadraticBezierTo(x(fx), y(v0 - 1.5), x(fx + 60), y(v0 + .5))
          ..lineTo(x(fx + 60), y(v0 + 2.6))
          ..quadraticBezierTo(x(fx), y(v0 + 1), x(fx - 40), y(v0 + 3))
          ..close(),
        field,
      );
    }
    // trees behind the houses
    for (final t in _trees) {
      if (t.$2 < 50) _tree(canvas, t);
    }
    _paintHouses(canvas);
    for (final t in _trees) {
      if (t.$2 >= 50) _tree(canvas, t);
    }
  }

  void _tree(Canvas canvas, (double, double, int, double) t) {
    final (X, v, kind, size) = t;
    final base = Offset(x(X), y(v) + 1.2 * u);
    final trunk = Paint()
      ..color = lit(const Color(0xFF4B3A2C), depth: .05)
      ..strokeWidth = .55 * u
      ..strokeCap = StrokeCap.round;
    final hgt = (kind == 1 ? 11.0 : 7.0) * u * size;
    canvas.drawLine(base, base.translate(0, -hgt * .45), trunk);
    if (bare) {
      // winter: bare branches, with a little snow
      final twig = Paint()
        ..color = trunk.color
        ..strokeWidth = .3 * u
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 5; i++) {
        final from = base.translate(0, -hgt * (.3 + .12 * i));
        final side = i.isEven ? 1.0 : -1.0;
        canvas.drawLine(from, from.translate(side * hgt * (kind == 1 ? .1 : .25), -hgt * .18), twig);
      }
      canvas.drawLine(base, base.translate(0, -hgt * .9), twig);
      return;
    }
    final leaf = lit(Color.lerp(leaves, Colors.black, .12 + .08 * (X % 3))!, facing: (sunX - .5));
    final crown = kind == 1
        ? Rect.fromCenter(center: base.translate(0, -hgt * .62), width: hgt * .3, height: hgt * .82)
        : Rect.fromCenter(center: base.translate(0, -hgt * .6), width: hgt * .9, height: hgt * .78);
    canvas.drawOval(crown, Paint()..color = leaf);
    // the side towards the sun is lighter
    canvas.drawOval(
      crown.deflate(crown.width * .12).shift(Offset((sunX - .5) * crown.width * .25, -crown.height * .08)),
      Paint()..color = Colors.white.withValues(alpha: .07 * daylight),
    );
    if (snow > .2) {
      canvas.drawOval(
        Rect.fromLTWH(crown.left + crown.width * .15, crown.top, crown.width * .7, crown.height * .3),
        Paint()..color = lit(const Color(0xFFF4F7FB)).withValues(alpha: .7 * snow),
      );
    }
  }

  void _paintHouses(Canvas canvas) {
    final night = 1 - daylight;
    final lights = scene.townLights;
    final facing = (sunX - .5) * 2;
    for (final (X, kind, seed) in _houses) {
      final b = _houseBase(X, seed);
      final (wallW, wallH) = _houseSize(kind, seed);
      final wallAlbedo = kind == 2
          ? const Color(0xFFCFC0A6) // the stone of a kulla
          : Color.lerp(const Color(0xFFF1EADF), const Color(0xFFE6D3B8), seed)!;
      final walls = Rect.fromLTRB(b.dx - wallW / 2, b.dy - wallH, b.dx + wallW / 2, b.dy);
      canvas.drawRect(walls, Paint()..color = lit(wallAlbedo, depth: .04, facing: facing));
      // the side in shade
      canvas.drawRect(
        facing >= 0
            ? Rect.fromLTRB(b.dx + wallW * .18, walls.top, walls.right, b.dy)
            : Rect.fromLTRB(walls.left, walls.top, b.dx - wallW * .18, b.dy),
        Paint()..color = Colors.black.withValues(alpha: .12 + .06 * daylight),
      );
      if (kind == 2) {
        // the wooden top floor of the kulla
        canvas.drawRect(
          Rect.fromLTRB(walls.left - .3 * u, walls.top, walls.right + .3 * u, walls.top + 1.6 * u),
          Paint()..color = lit(const Color(0xFF6B4A32), depth: .04),
        );
      }
      // the roof: red tiles, white with snow in winter
      final roofH = (kind == 2 ? 2.2 : 2.6) * u;
      final eave = .9 * u;
      final roof = Path()
        ..moveTo(walls.left - eave, walls.top + .2 * u)
        ..lineTo(b.dx - wallW * .18, walls.top - roofH)
        ..lineTo(b.dx + wallW * .18, walls.top - roofH)
        ..lineTo(walls.right + eave, walls.top + .2 * u)
        ..close();
      final tiles = Color.lerp(const Color(0xFFB4532F), const Color(0xFF8E3F27), seed)!;
      final roofColor = Color.lerp(tiles, const Color(0xFFEFF3F7), snow * .9)!;
      canvas.drawPath(roof, Paint()..color = lit(roofColor, depth: .04, facing: .3));
      // a chimney
      if (seed > .3) {
        canvas.drawRect(
          Rect.fromLTWH(b.dx + wallW * .2, walls.top - roofH - .4 * u, .8 * u, 1.6 * u),
          Paint()..color = lit(const Color(0xFF8A6B55), depth: .04),
        );
      }
      // windows: dark by day; lit one by one in the evening
      final winPaint = Paint();
      final windows = [
        (b.translate(-1.1 * u, -wallH * .5), seed),
        if (kind != 0) (b.translate(1.2 * u, -wallH * .75), (seed + .37) % 1),
      ];
      for (final (c, order) in windows) {
        final on = night > .3 && order < lights;
        final r = Rect.fromCenter(center: c, width: 1.1 * u, height: 1.4 * u);
        if (on) {
          final glow = dim(Color.lerp(const Color(0xFFFFCF73), const Color(0xFFFFEFCB), order)!);
          winPaint.color = glow.withValues(alpha: .2);
          canvas.drawCircle(c, 2.2 * u, winPaint);
          winPaint.color = glow;
        } else {
          winPaint.color = lit(const Color(0xFF3A3F4A), depth: .04);
        }
        canvas.drawRect(r, winPaint);
      }
    }
  }

  /// The lake, mirroring the sky, the hills and the houses; frozen in the depth of winter.
  void _lake(Canvas canvas) {
    final shore = Path()..moveTo(x(-10), y(_shoreV));
    for (var X = -10.0; X <= 410; X += 20) {
      shore.lineTo(x(X), y(_shoreV + 1.2 * math.sin(X * .045)));
    }
    shore
      ..lineTo(x(410), y(_meadowV + 4))
      ..lineTo(x(-10), y(_meadowV + 4))
      ..close();
    final frozen = _smooth((snow - .6) / .3);
    // the water takes the sky's colours, upside down and a little darker
    final skyNear = Color.lerp(_haze, _night, .08 + .3 * (1 - daylight))!;
    final skyHigh = Color.lerp(_sky, const Color(0xFF0D2236), .3)!;
    final water = [
      dim(Color.lerp(skyNear, const Color(0xFFDCE6EE), frozen * .6)!),
      dim(Color.lerp(skyHigh, const Color(0xFFB9C8D6), frozen * .6)!),
    ];
    canvas.drawPath(shore, Paint()..shader = ui.Gradient.linear(Offset(0, y(_shoreV)), Offset(0, y(_meadowV)), water));
    canvas.save();
    canvas.clipPath(shore);
    // the slope mirrored in the water: dark near the shore, fading out
    canvas.save();
    canvas.translate(0, 2 * y(_shoreV));
    canvas.scale(1, -1);
    final reflection = lit(Color.lerp(grass, Colors.black, .35)!);
    canvas.drawPath(
      _ridge(_slope, bottom: _shoreV),
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, y(_shoreV)), Offset(0, y(_shoreV - 10)), [
          reflection.withValues(alpha: .55 * (1 - frozen * .7)),
          reflection.withValues(alpha: 0),
        ]),
    );
    canvas.restore();
    // a bright line where the water meets the shore
    canvas.drawRect(
      Rect.fromLTRB(0, y(_shoreV) - .3 * u, w, y(_shoreV) + .6 * u),
      Paint()..color = Colors.white.withValues(alpha: .10 + .08 * daylight),
    );
    if (frozen > .02) {
      // cracks in the ice
      final crack = Paint()
        ..color = Colors.white.withValues(alpha: .25 * frozen)
        ..strokeWidth = .25 * u
        ..style = PaintingStyle.stroke;
      for (var i = 0; i < 6; i++) {
        final X = 30.0 + i * 64;
        canvas.drawPath(
          Path()
            ..moveTo(x(X), y(_shoreV + 4 + i % 3 * 3))
            ..lineTo(x(X + 14), y(_shoreV + 6 + i % 2 * 4))
            ..lineTo(x(X + 26), y(_shoreV + 5 + i % 3 * 2)),
          crack,
        );
      }
    }
    canvas.restore();
  }

  /// The meadow in front: grass with flowers in spring, golden in summer, brown in autumn, snow in winter.
  void _meadow(Canvas canvas) {
    final rnd = math.Random(77);
    final edge = Path()..moveTo(x(-10), y(_meadowV + 2));
    // a fringe of blades along the top of the meadow
    for (var X = -10.0; X <= 410; X += 3) {
      final tall = 1.6 + rnd.nextDouble() * 3.2;
      edge
        ..lineTo(x(X + .6), y(_meadowV + 1.6 - tall * (snow > .6 ? .2 : 1)))
        ..lineTo(x(X + 1.5), y(_meadowV + 2 + rnd.nextDouble()));
    }
    edge
      ..lineTo(x(410), y(104))
      ..lineTo(x(-10), y(104))
      ..close();
    canvas.drawPath(
      edge,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, y(_meadowV - 2)), Offset(0, y(100)), [
          lit(grass, facing: .2),
          lit(Color.lerp(grass, Colors.black, .45)!),
        ]),
    );
    // reeds by the water on the left, and a few rocks
    final reed = Paint()
      ..color = lit(Color.lerp(grass, const Color(0xFF6B5A2E), .4)!)
      ..strokeWidth = .45 * u
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 9; i++) {
      final X = 6.0 + i * 3.4;
      final b = Offset(x(X), y(_meadowV + 2));
      canvas.drawLine(b, b.translate((i % 3 - 1) * .8 * u, -(5 + (i * 7 % 5)) * u), reed);
    }
    final rock = Paint()..color = lit(const Color(0xFF7A7570), facing: (sunX - .5) * 2);
    for (final (X, r) in const [(330.0, 2.6), (338.0, 1.6), (210.0, 1.8)]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x(X), y(_meadowV + 3.4)), width: r * 2.4 * u, height: r * 1.3 * u),
        rock,
      );
    }
    // spring flowers, summer poppies
    final season = Color(scene.season);
    final green = (season.g - season.r).clamp(0.0, 1.0);
    final golden = (season.r - season.b).clamp(0.0, 1.0);
    if (snow < .3 && daylight > .2) {
      final flower = Paint();
      final r2 = math.Random(5);
      for (var i = 0; i < 46; i++) {
        final c = Offset(x(r2.nextDouble() * 400), y(_meadowV + 4 + r2.nextDouble() * 14));
        final spring = r2.nextDouble() < green * 2.2;
        final poppy = !spring && r2.nextDouble() < golden * .6;
        if (!spring && !poppy) continue;
        flower.color = dim(
          spring
              ? [const Color(0xFFFFFFFF), const Color(0xFFFFE066), const Color(0xFFE7B8FF)][i % 3]
              : const Color(0xFFE5402F),
        ).withValues(alpha: .55 * daylight);
        canvas.drawCircle(c, (.5 + r2.nextDouble() * .4) * u, flower);
      }
    }
  }

  // ---------- What moves ----------

  /// The water's ripples, the sun or moon glittering on it, the lights of the village in the water, the smoke of
  /// the chimneys in the cold months, and the tall grass in the wind.
  void paintMotion(Canvas canvas, double t, {Offset? sun, Offset? moon, double moonLight = 0}) {
    if (!village) return;
    final frozen = _smooth((snow - .6) / .3);
    final shoreY = y(_shoreV), meadowY = y(_meadowV);
    final waterH = meadowY - shoreY;
    final paint = Paint()..strokeCap = StrokeCap.round;

    if (frozen < .95) {
      final calm = 1 - frozen;
      // ripples
      final rnd = math.Random(31);
      final ripple = dim(Color.lerp(_haze, Colors.white, .5)!);
      for (var i = 0; i < 22; i++) {
        final X = rnd.nextDouble() * w, Y = shoreY + (.15 + rnd.nextDouble() * .8) * waterH;
        final len = (6 + rnd.nextDouble() * 18) * (.6 + (Y - shoreY) / waterH);
        final a = _wave(t, 3 + rnd.nextDouble() * 4, rnd.nextDouble() * 6.3);
        final drift = math.sin(t * .3 + i) * 6;
        paint
          ..strokeWidth = .9
          ..color = ripple.withValues(alpha: (.05 + .14 * a) * calm * (.35 + .65 * daylight));
        canvas.drawLine(Offset(X + drift - len / 2, Y), Offset(X + drift + len / 2, Y), paint);
      }
      // the sun's (or the moon's) path of light on the water
      void glitter(Offset at, Color color, double strength) {
        if (strength <= .02) return;
        final r = math.Random(at.dx.round());
        for (var i = 0; i < 26; i++) {
          final f = r.nextDouble();
          final Y = shoreY + (.06 + f * .92) * waterH;
          final spread = (6 + 26 * f) * (1 + .4 * math.sin(t * 1.3 + i));
          final X = at.dx + (r.nextDouble() - .5) * spread * 2;
          final a = math.pow(_wave(t, .9 + r.nextDouble() * 1.4, r.nextDouble() * 6.3), 3).toDouble();
          final len = 3 + r.nextDouble() * 9;
          paint
            ..strokeWidth = 1.2
            ..color = color.withValues(alpha: strength * a * calm);
          canvas.drawLine(Offset(X - len / 2, Y), Offset(X + len / 2, Y), paint);
        }
      }

      if (sun != null) glitter(sun, dim(Color.lerp(pal.sun, Colors.white, .3)!), .65 * daylight);
      if (moon != null) glitter(moon, dim(const Color(0xFFF6F1DE)), .5 * moonLight * (1 - daylight));

      // the windows' lights in the water
      if (daylight < .7 && scene.townLights > .02) {
        final glow = dim(const Color(0xFFFFD58A));
        for (final (c, order) in windows()) {
          if (order >= scene.townLights) continue;
          final mirror = 2 * shoreY - c.dy;
          if (mirror < shoreY || mirror > meadowY) continue;
          final a = (.25 + .2 * _wave(t, 1.6, order * 9)) * (1 - daylight) * calm;
          paint
            ..strokeWidth = 1.1
            ..color = glow.withValues(alpha: a);
          for (var k = 0; k < 3; k++) {
            final yy = mirror + k * 3.2;
            final wob = math.sin(t * 2.2 + order * 20 + k) * 1.4;
            canvas.drawLine(Offset(c.dx - 2 + wob, yy), Offset(c.dx + 2 + wob, yy), paint);
          }
        }
      }
    }

    // smoke from the chimneys when it is cold
    final cold = math.max(snow, _coldness - .35);
    if (cold > .05) {
      final smoke = dim(Color.lerp(const Color(0xFFE8E8EE), _haze, .3)!);
      final puff = Paint();
      for (final (X, kind, seed) in _houses) {
        if (seed <= .3) continue;
        final b = _houseBase(X, seed);
        final (wallW, wallH) = _houseSize(kind, seed);
        final top = Offset(b.dx + wallW * .2 + .4 * u, b.dy - wallH - 3.6 * u);
        for (var i = 0; i < 4; i++) {
          final age = ((t * .18 + seed * 3 + i / 4) % 1.0);
          final c = top.translate(age * 5 * u + math.sin(t * .7 + i) * .6 * u, -age * 9 * u);
          puff.color = smoke.withValues(alpha: .22 * cold * (1 - age) * (.4 + .6 * daylight));
          canvas.drawCircle(c, (.6 + age * 1.8) * u, puff);
        }
      }
    }

    // tall grass swaying in front
    if (snow < .6) {
      final blade = Paint()
        ..color = lit(Color.lerp(grass, Colors.black, .3)!)
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final rnd = math.Random(19);
      final path = Path();
      for (var i = 0; i < 70; i++) {
        final X = rnd.nextDouble() * w;
        final Y = y(_meadowV + 6 + rnd.nextDouble() * 16);
        final tall = (3 + rnd.nextDouble() * 5) * u;
        final sway = math.sin(t * (.8 + rnd.nextDouble() * .5) + X * .02) * tall * .18;
        path
          ..moveTo(X, Y)
          ..quadraticBezierTo(X + sway * .3, Y - tall * .55, X + sway, Y - tall);
      }
      canvas.drawPath(path, blade);
    }
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);

double _smooth(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double _wave(double seconds, double period, [double phase = 0]) =>
    .5 + .5 * math.sin(seconds / period * 2 * math.pi + phase);

// ---------- Friday ----------

/// The Friday look: a band of eight-pointed stars along the top of the sky and a pointed arch framing it, in thin
/// gold, and a soft golden light from above. Brighter at night, quieter by day.
void paintFridayFrame(
  Canvas canvas,
  Size size, {
  required double daylight,
  required double topInset,
  required Color Function(Color) dim,
}) {
  final w = size.width, h = size.height;
  final gold = dim(const Color(0xFFE9C46A));
  final strength = .55 + .45 * (1 - daylight);
  // a golden light from above
  final c = Offset(w / 2, 0);
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = ui.Gradient.radial(
        c,
        h * .55,
        [gold.withValues(alpha: .10 * strength), gold.withValues(alpha: .03 * strength), gold.withValues(alpha: 0)],
        const [0, .5, 1],
      ),
  );
  final line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = .9
    ..color = gold.withValues(alpha: .34 * strength);
  // the band of stars
  const tile = 30.0;
  // just under the status bar, above the header
  final bandY = topInset + 6;
  final n = (w / tile).ceil() + 1;
  final x0 = (w - (n - 1) * tile) / 2;
  for (var i = 0; i < n; i++) {
    final cx = x0 + i * tile;
    final edgeFade = (1 - ((cx - w / 2).abs() / (w / 2)) * .6).clamp(0.0, 1.0);
    line.color = gold.withValues(alpha: .30 * strength * edgeFade);
    _star8(canvas, Offset(cx, bandY), 5.2, line);
    // little diamonds between the stars
    final d = Offset(cx + tile / 2, bandY);
    canvas.drawPath(
      Path()
        ..moveTo(d.dx, d.dy - 2.4)
        ..lineTo(d.dx + 2.4, d.dy)
        ..lineTo(d.dx, d.dy + 2.4)
        ..lineTo(d.dx - 2.4, d.dy)
        ..close(),
      line,
    );
  }
  line.color = gold.withValues(alpha: .22 * strength);
  canvas.drawLine(Offset(0, bandY + 8), Offset(w, bandY + 8), line);

  // the pointed arch, as in a mihrab: up the sides and meeting in a point at the top
  final bottom = h - Landscape.heightFor(size) * 1.25;
  final side = h * .36;
  final apex = h * .19;
  for (final (inset, a) in [(12.0, .26), (18.0, .14)]) {
    line.color = gold.withValues(alpha: a * strength);
    final arch = Path()
      ..moveTo(inset, bottom)
      ..lineTo(inset, side)
      ..cubicTo(
        inset,
        side - (side - apex) * .55,
        w / 2 - w * .18,
        apex + (side - apex) * .25,
        w / 2,
        apex + inset - 12,
      )
      ..cubicTo(w / 2 + w * .18, apex + (side - apex) * .25, w - inset, side - (side - apex) * .55, w - inset, side)
      ..lineTo(w - inset, bottom);
    canvas.drawPath(arch, line);
  }
}

/// The rosette behind the countdown on Fridays: a slowly turning star of sixteen points in a circle.
void paintFridayRosette(
  Canvas canvas,
  Offset c,
  double r,
  double t, {
  required double alpha,
  required Color Function(Color) dim,
}) {
  if (alpha <= .01) return;
  final gold = dim(const Color(0xFFE9C46A));
  final line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = .9
    ..color = gold.withValues(alpha: alpha);
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(t * 2 * math.pi / 360); // one turn in six minutes
  canvas.drawCircle(Offset.zero, r, line);
  line.color = gold.withValues(alpha: alpha * .7);
  canvas.drawCircle(Offset.zero, r * .93, line);
  // two eight-pointed stars, turned against each other: a sixteen-pointed star
  _star8(canvas, Offset.zero, r * .92, line);
  canvas.rotate(math.pi / 8);
  _star8(canvas, Offset.zero, r * .92, line..color = gold.withValues(alpha: alpha * .55));
  canvas.restore();
}

/// An eight-pointed star (two squares, one turned by 45°).
void _star8(Canvas canvas, Offset c, double r, Paint paint) {
  final path = Path();
  for (var k = 0; k < 2; k++) {
    for (var i = 0; i < 4; i++) {
      final a = k * math.pi / 4 + i * math.pi / 2;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
  }
  canvas.drawPath(path, paint);
}
