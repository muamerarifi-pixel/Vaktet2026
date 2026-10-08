import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../logic/prayer.dart';
import 'colors.dart';

/// The land under the full-screen sky, drawn as layers of silhouette: a far mountain range, a hill with a mosque,
/// a nearer hill with a small village and cypresses, a lake, and the dark shore in front.
///
/// Every layer takes its colour from the sky: the far range is almost the colour of the horizon, and each nearer
/// layer is a step darker, so the land always belongs to the hour (gold at sunset, blue at night, pale in the
/// winter haze). Details are kept small and few; at night only the windows and the minaret's balcony light up.
///
/// Laid out in a box at the bottom of the screen: x from 0 to 400 across, v from 0 (the top of the box) to 100
/// (the bottom of the screen); the mountains rise above the box.
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

  /// Draw the village, the lake and the shore (otherwise only the mountains and the hill).
  final bool village;

  /// The day shown is a Friday: the mosque's crescents and windows turn gold, and it glows softly.
  final bool friday;

  /// A great night, or Ramazan: a short string of lights hangs from the minaret after dark.
  final bool festive;

  double get w => size.width;
  double get h => size.height;

  /// Height of the box.
  static double heightFor(Size size) => math.min(.21 * size.height, 184.0);

  late final double boxH = heightFor(size);
  double get top => h - boxH;

  /// One unit of the box, the same across and up (for buildings, which must not stretch).
  double get u => boxH / 100;
  double x(double X) => X / 400 * w;
  double y(double v) => top + v * boxH / 100;

  /// Where the sun and the moon go down: behind the mountains.
  static double horizonFor(Size size) => size.height - heightFor(size) * 1.02;

  // ---------- Colour ----------

  /// 1 in full daylight, about .1 in the depth of the night.
  late final double daylight = (1 - pal.stars * .9).clamp(0.0, 1.0);

  /// How strongly the low sun colours the land (around sunrise and sunset).
  late final double warm = () {
    final sp = scene.sunProgress;
    final edge = math.min(sp.abs(), (sp - 1).abs());
    return _smooth(1 - edge / .2);
  }();

  /// Where the sun is across the screen (0–1).
  late final double sunX = .5 - .42 * math.cos(math.pi * scene.sunProgress.clamp(0.0, 1.0));

  late final Color _haze = pal.colors.last;
  late final Color _sky = pal.colors[pal.colors.length ~/ 2];

  double get snow => scene.snow;

  /// The darkest colour of the land: the night sky's blue after dark, the season's colour (deep and quiet) by
  /// day, paler under snow and a little lighter under a bright moon.
  late final Color _ground = () {
    final night = Color.lerp(pal.colors.first, const Color(0xFF02040C), .55)!;
    final day = Color.lerp(Color(scene.season), const Color(0xFF1C2626), .58)!;
    var g = Color.lerp(night, day, daylight)!;
    g = Color.lerp(g, Color.lerp(const Color(0xFF2A3344), const Color(0xFFB8C4D0), daylight)!, snow * .55)!;
    if (scene.moon.up) g = Color.lerp(g, const Color(0xFF8C9AB8), .08 * scene.moon.illumination * (1 - daylight))!;
    return g;
  }();

  /// The colour of a layer: [t] 0 is the horizon's haze, 1 the darkest ground.
  Color layer(double t) {
    var c = Color.lerp(_haze, _ground, t)!;
    if (scene.tintStrength > 0) c = Color.lerp(c, Color(scene.tint), scene.tintStrength * .35)!;
    return dim(c);
  }

  late final Color farColor = layer(.42);
  late final Color midColor = layer(.62);
  late final Color nearColor = layer(.8);
  late final Color shoreColor = layer(.93);

  /// Snow on the high peaks: through most of the year, only on the tops in summer.
  double get _peakSnow => math.max(snow, .1 + .7 * math.pow(scene.cold, 1.3));

  // ---------- Shapes ----------

  /// A smooth line through [pts] (x, v), closed down to the bottom of the screen.
  Path _smoothRidge(List<(double, double)> pts) {
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
      ..lineTo(x(pts.last.$1), y(104))
      ..lineTo(x(pts.first.$1), y(104))
      ..close();
  }

  /// The height (v) of a line through [pts] at [X], eased between the points.
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

  static const List<(double, double)> _range = [
    (-10, 8),
    (20, -4),
    (38, 2),
    (60, -16),
    (78, -6),
    (96, -12),
    (120, -30),
    (138, -20),
    (150, -24),
    (172, -6),
    (196, 2),
    (222, -2),
    (250, 6),
    (280, -8),
    (304, -20),
    (324, -34),
    (342, -22),
    (360, -26),
    (384, -8),
    (410, 0),
  ];

  static const List<(double, double)> _hill = [
    (-10, 24),
    (40, 18),
    (90, 22),
    (140, 16),
    (190, 19),
    (236, 13),
    (262, 12),
    (290, 14),
    (340, 21),
    (380, 18),
    (410, 22),
  ];

  static const List<(double, double)> _near = [
    (-10, 42),
    (30, 36),
    (80, 39),
    (130, 45),
    (180, 48),
    (230, 47),
    (280, 43),
    (330, 37),
    (370, 35),
    (410, 39),
  ];

  static const List<(double, double)> _shore = [(-10, 74), (80, 72), (160, 75), (240, 73), (320, 70), (410, 74)];

  static const double _waterV = 56;

  /// x (0–400) of the mosque.
  static const double mosqueX = 262;

  /// The village: (x, width, height of the walls, seed for its window).
  static const List<(double, double, double, double)> _houses = [
    (62, 6.4, 3.8, .12),
    (70, 5.2, 3.2, .58),
    (78, 7.0, 4.4, .33),
    (88, 5.6, 3.4, .81),
    (97, 6.2, 4.0, .45),
    (324, 6.0, 3.6, .27),
    (333, 7.2, 4.6, .69),
    (343, 5.4, 3.2, .05),
    (352, 6.6, 4.0, .9),
  ];

  /// Cypresses: (x, height).
  static const List<(double, double)> _cypresses = [(44, 10), (50, 13), (108, 9), (312, 12), (318, 9), (364, 11)];

  // ---------- Painting ----------

  /// Everything that does not move.
  void paintStill(Canvas canvas) {
    _mountains(canvas);
    _hillAndMosque(canvas);
    if (village) {
      _nearHill(canvas);
      _lake(canvas);
      _shoreline(canvas);
    }
  }

  void _mountains(Canvas canvas) {
    final outline = Path()..moveTo(x(_range.first.$1), y(_range.first.$2));
    for (final (X, v) in _range.skip(1)) {
      outline.lineTo(x(X), y(v));
    }
    outline
      ..lineTo(x(_range.last.$1), y(104))
      ..lineTo(x(_range.first.$1), y(104))
      ..close();
    canvas.drawPath(outline, Paint()..color = farColor);

    canvas.save();
    canvas.clipPath(outline);
    // snow on the peaks, with a soft lower edge; pink in the alpenglow
    final snowLine = _lerp(-28, 6, _peakSnow);
    final snowColor = Color.lerp(
      Color.lerp(farColor, dim(const Color(0xFFF2F5FA)), .25 + .45 * daylight)!,
      dim(const Color(0xFFFFC4B4)),
      warm * daylight * .35,
    )!;
    canvas.drawRect(
      Rect.fromLTRB(0, y(-50), w, y(snowLine + 5)),
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, y(snowLine - 4)), Offset(0, y(snowLine + 5)), [
          snowColor,
          snowColor.withValues(alpha: 0),
        ]),
    );
    // the side of each peak away from the sun is a shade darker
    final shadeLeft = sunX >= .5;
    final shade = Paint()..color = Colors.black.withValues(alpha: .05 + .09 * daylight);
    for (var i = 1; i < _range.length - 1; i++) {
      final (px, pv) = _range[i];
      if (!(pv < _range[i - 1].$2 && pv < _range[i + 1].$2)) continue;
      final step = shadeLeft ? -1 : 1;
      var k = i;
      while (k + step >= 0 && k + step < _range.length && _range[k + step].$2 > _range[k].$2) {
        k += step;
      }
      final face = Path()..moveTo(x(px), y(pv));
      for (var j = i + step; step > 0 ? j <= k : j >= k; j += step) {
        face.lineTo(x(_range[j].$1), y(_range[j].$2));
      }
      // down the slope to the valley, then back up a ridge line to the peak: no vertical edges
      final (vx, vv) = _range[k];
      face.lineTo(x(px + (vx - px) * .3), y(math.max(vv, pv) + (40 - math.max(vv, pv)) * .9));
      face.close();
      canvas.drawPath(face, shade);
    }
    canvas.restore();
  }

  void _hillAndMosque(Canvas canvas) {
    canvas.drawPath(_smoothRidge(_hill), Paint()..color = midColor);
    if (mosque) mosqueAt(canvas, Offset(x(mosqueX), y(_heightAt(_hill, mosqueX) + 1.2)), u * .8, midColor);
  }

  /// The mosque as one quiet silhouette in [color]: a hall under one great dome, two half domes and a slender
  /// pencil minaret, with crescents. The low sun (or snow) catches the rim of the dome; after dark a few windows
  /// and the minaret's balcony are lit; on Fridays the crescents and the light are gold.
  void mosqueAt(Canvas canvas, Offset base, double s, Color color) {
    final mx = base.dx, by = base.dy;
    final night = _smooth((.62 - daylight) / .4);
    final gold = dim(const Color(0xFFE8C26A));
    final silhouette = Color.lerp(color, Colors.black, .14)!;

    if (friday) {
      // a soft golden light around the mosque
      final c = Offset(mx + 4 * s, by - 10 * s);
      final r = 46 * s;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = ui.Gradient.radial(c, r, [gold.withValues(alpha: .10 + .16 * night), gold.withValues(alpha: 0)]),
      );
    }

    final body = Path()
      // the hall
      ..addRect(Rect.fromLTRB(mx - 13 * s, by - 8 * s, mx + 13 * s, by + 2 * s))
      // the drum
      ..addRect(Rect.fromLTRB(mx - 7 * s, by - 10.5 * s, mx + 7 * s, by - 7.5 * s))
      // the half domes
      ..addArc(Rect.fromCircle(center: Offset(mx - 9 * s, by - 8 * s), radius: 3.8 * s), math.pi, math.pi)
      ..addArc(Rect.fromCircle(center: Offset(mx + 9 * s, by - 8 * s), radius: 3.8 * s), math.pi, math.pi);
    // the great dome, a touch taller than a half circle
    final domeY = by - 10.5 * s;
    final dome = Path()
      ..moveTo(mx - 7.4 * s, domeY)
      ..cubicTo(mx - 7.4 * s, domeY - 6.4 * s, mx - 3.6 * s, domeY - 8.6 * s, mx, domeY - 8.8 * s)
      ..cubicTo(mx + 3.6 * s, domeY - 8.6 * s, mx + 7.4 * s, domeY - 6.4 * s, mx + 7.4 * s, domeY)
      ..close();
    body.addPath(dome, Offset.zero);
    // the minaret: base, shaft, balcony and a pencil cap
    final mxR = mx + 17 * s;
    final shaftTop = by - 38 * s;
    final balconyY = by - 29 * s;
    body
      ..addRect(Rect.fromLTRB(mxR - 1.7 * s, by - 6 * s, mxR + 1.7 * s, by + 2 * s))
      ..addRect(Rect.fromLTRB(mxR - 1.05 * s, shaftTop, mxR + 1.05 * s, by - 6 * s))
      ..addRect(Rect.fromLTRB(mxR - 2 * s, balconyY - .5 * s, mxR + 2 * s, balconyY + .7 * s))
      ..addPath(
        Path()
          ..moveTo(mxR - 1.25 * s, shaftTop)
          ..lineTo(mxR, shaftTop - 9.5 * s)
          ..lineTo(mxR + 1.25 * s, shaftTop)
          ..close(),
        Offset.zero,
      );
    canvas.drawPath(body, Paint()..color = silhouette);

    // a thin rim of light on the dome: the low sun on its side, or snow on top
    final sunRim = warm * daylight, snowRim = .6 * snow * daylight;
    if (math.max(sunRim, snowRim) > .04) {
      final shift = snowRim > sunRim ? Offset(0, .9 * s) : Offset((sunX < .5 ? 1 : -1) * .9 * s, .6 * s);
      final rimColor = snowRim > sunRim ? dim(const Color(0xFFEFF3F8)) : dim(pal.sun);
      canvas.drawPath(
        Path.combine(PathOperation.difference, dome, dome.shift(shift)),
        Paint()..color = rimColor.withValues(alpha: .6 * math.max(sunRim, snowRim)),
      );
    }

    // the crescents: the colour of the silhouette, gold on Fridays
    final finial = friday ? gold : silhouette;
    _crescent(canvas, Offset(mx, domeY - 8.8 * s), 2.6 * s, finial, s);
    _crescent(canvas, Offset(mxR, shaftTop - 9.5 * s), 2.2 * s, finial, s);

    // after dark: a few windows and the balcony are lit
    if (night > .02) {
      final light = friday ? gold : dim(const Color(0xFFFFD9A0));
      final dot = Paint()..color = light.withValues(alpha: .85 * night);
      for (final dx in const [-9.0, -4.5, 0.0, 4.5, 9.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(mx + dx * s, by - 3.4 * s), width: .9 * s, height: 2.2 * s),
            Radius.circular(.45 * s),
          ),
          dot,
        );
      }
      canvas.drawCircle(Offset(mxR, balconyY), 2.6 * s, Paint()..color = light.withValues(alpha: .22 * night));
      canvas.drawCircle(Offset(mxR, balconyY), .55 * s, dot);
      if (festive) {
        // a short string of lights from the balcony down to the dome
        final a = Offset(mxR - 2 * s, balconyY + .4 * s), b = Offset(mx + 3 * s, domeY - 7.6 * s);
        for (var i = 1; i < 9; i++) {
          final t = i / 9;
          canvas.drawCircle(Offset.lerp(a, b, t)! + Offset(0, 2.6 * s * math.sin(math.pi * t)), .38 * s, dot);
        }
      }
    }
  }

  void _crescent(Canvas canvas, Offset tip, double height, Color color, double s) {
    canvas.drawLine(
      tip,
      tip.translate(0, -height * .4),
      Paint()
        ..color = color
        ..strokeWidth = .32 * s
        ..strokeCap = StrokeCap.round,
    );
    final c = tip.translate(0, -height * .72);
    final r = height * .3;
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: c, radius: r)),
        Path()..addOval(Rect.fromCircle(center: c.translate(r * .42, -r * .18), radius: r * .8)),
      ),
      Paint()..color = color,
    );
  }

  /// Where the windows of the village are, for the lights and their reflections: (centre, order they go out).
  List<(Offset, double)> windows() => [
    for (final (X, wd, ht, seed) in _houses)
      (Offset(x(X) + (seed - .5) * wd * .4 * u, y(_heightAt(_near, X) + 1.6) - ht * .45 * u), seed),
  ];

  void _nearHill(Canvas canvas) {
    final path = _smoothRidge(_near);
    // the village and the cypresses, as part of the same silhouette
    for (final (X, wd, ht, _) in _houses) {
      final b = Offset(x(X), y(_heightAt(_near, X) + 1.6));
      final half = wd / 2 * u;
      path.addPath(
        Path()
          ..moveTo(b.dx - half, b.dy)
          ..lineTo(b.dx - half, b.dy - ht * u)
          ..lineTo(b.dx - half - .5 * u, b.dy - ht * u)
          ..lineTo(b.dx, b.dy - (ht + 2.6) * u)
          ..lineTo(b.dx + half + .5 * u, b.dy - ht * u)
          ..lineTo(b.dx + half, b.dy - ht * u)
          ..lineTo(b.dx + half, b.dy)
          ..close(),
        Offset.zero,
      );
    }
    for (final (X, ht) in _cypresses) {
      final b = Offset(x(X), y(_heightAt(_near, X) + 1));
      final hh = ht * u, ww = 1.5 * u;
      path.addPath(
        Path()
          ..moveTo(b.dx, b.dy - hh)
          ..cubicTo(b.dx + ww * 1.1, b.dy - hh * .7, b.dx + ww, b.dy - hh * .2, b.dx + ww * .5, b.dy)
          ..lineTo(b.dx - ww * .5, b.dy)
          ..cubicTo(b.dx - ww, b.dy - hh * .2, b.dx - ww * 1.1, b.dy - hh * .7, b.dx, b.dy - hh)
          ..close(),
        Offset.zero,
      );
    }
    canvas.drawPath(path, Paint()..color = nearColor);

    // the windows, lit one by one in the evening
    final night = 1 - daylight;
    if (night > .35 && scene.townLights > .02) {
      final a = (night - .35) / .65;
      final dot = Paint();
      for (final (c, order) in windows()) {
        if (order >= scene.townLights) continue;
        final color = dim(Color.lerp(const Color(0xFFFFCF80), const Color(0xFFFFEED0), order)!);
        dot.color = color.withValues(alpha: .18 * a);
        canvas.drawCircle(c, 1.8 * u, dot);
        dot.color = color.withValues(alpha: .9 * a);
        canvas.drawRect(Rect.fromCenter(center: c, width: .8 * u, height: 1 * u), dot);
      }
    }
  }

  late final double _frozen = _smooth((snow - .6) / .3);

  /// The lake: the sky's colours mirrored, a little darker; pale and still when it freezes.
  void _lake(Canvas canvas) {
    final water = Rect.fromLTRB(0, y(_waterV), w, h);
    final near = Color.lerp(_haze, _ground, .35)!;
    final deep = Color.lerp(_sky, _ground, .7)!;
    final ice = Color.lerp(farColor, dim(const Color(0xFFDDE5EE)), .35 + .3 * daylight)!;
    canvas.drawRect(
      water,
      Paint()
        ..shader = ui.Gradient.linear(water.topLeft, Offset(0, y(_shore.first.$2)), [
          Color.lerp(dim(near), ice, _frozen)!,
          Color.lerp(dim(deep), ice, _frozen * .8)!,
        ]),
    );
    // the hill mirrored, fading out below the shore
    canvas.save();
    canvas.clipRect(water);
    canvas.translate(0, 2 * y(_waterV));
    canvas.scale(1, -1);
    canvas.drawPath(
      _smoothRidge(_near),
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, y(_waterV)), Offset(0, y(_waterV - 9)), [
          nearColor.withValues(alpha: .7 * (1 - _frozen * .6)),
          nearColor.withValues(alpha: 0),
        ]),
    );
    canvas.restore();
    // a fine bright line along the far shore
    canvas.drawRect(
      Rect.fromLTRB(0, y(_waterV) - .3, w, y(_waterV) + .6),
      Paint()..color = Colors.white.withValues(alpha: .06 + .07 * daylight),
    );
  }

  void _shoreline(Canvas canvas) {
    final path = _smoothRidge(_shore);
    // a few reeds at the water's edge on the left
    for (var i = 0; i < 6; i++) {
      final X = 8.0 + i * 2.6;
      final b = Offset(x(X), y(_heightAt(_shore, X) + 1));
      final hh = (4.0 + (i * 7 % 5)) * u;
      final lean = (i % 3 - 1) * .7 * u;
      path.addPath(
        Path()
          ..moveTo(b.dx - .25 * u, b.dy)
          ..quadraticBezierTo(b.dx + lean * .3, b.dy - hh * .6, b.dx + lean, b.dy - hh)
          ..quadraticBezierTo(b.dx + lean * .3 + .3 * u, b.dy - hh * .6, b.dx + .25 * u, b.dy)
          ..close(),
        Offset.zero,
      );
    }
    canvas.drawPath(path, Paint()..color = shoreColor);
  }

  // ---------- What moves ----------

  /// The water: a few slow glints, the sun's or the moon's path of light, and the windows mirrored at night.
  void paintMotion(Canvas canvas, double t, {Offset? sun, Offset? moon, double moonLight = 0}) {
    if (!village || _frozen > .95) return;
    final calm = 1 - _frozen;
    final top = y(_waterV), bottom = y(_heightAt(_shore, 200) - 1);
    final depth = bottom - top;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = .8;

    // a few long, slow glints
    final rnd = math.Random(31);
    final glint = dim(Color.lerp(_haze, Colors.white, .55)!);
    for (var i = 0; i < 9; i++) {
      final yy = top + (.18 + rnd.nextDouble() * .7) * depth;
      final xx = rnd.nextDouble() * w + math.sin(t * .15 + i) * 10;
      final len = 14 + rnd.nextDouble() * 30;
      paint.color = glint.withValues(alpha: (.04 + .09 * _wave(t, 5 + rnd.nextDouble() * 4, i * 1.3)) * calm);
      canvas.drawLine(Offset(xx - len / 2, yy), Offset(xx + len / 2, yy), paint);
    }

    // the path of light under the sun or the moon
    void lightPath(Offset at, Color color, double strength) {
      if (strength <= .02) return;
      final r = math.Random(7);
      for (var i = 0; i < 14; i++) {
        final f = (i + .5) / 14;
        final yy = top + f * depth * .95;
        final spread = 3 + 18 * f;
        final xx = at.dx + (r.nextDouble() - .5) * 2 * spread;
        final len = 3 + 10 * f;
        final a = math.pow(_wave(t, 1.4 + r.nextDouble() * 1.6, r.nextDouble() * 6.3), 2).toDouble();
        paint
          ..strokeWidth = 1
          ..color = color.withValues(alpha: strength * (.25 + .75 * a) * (1 - .5 * f) * calm);
        canvas.drawLine(Offset(xx - len / 2, yy), Offset(xx + len / 2, yy), paint);
      }
    }

    if (sun != null) lightPath(sun, dim(Color.lerp(pal.sun, Colors.white, .25)!), .55 * daylight);
    if (moon != null) lightPath(moon, dim(const Color(0xFFF2EEDC)), .45 * moonLight * (1 - daylight));

    // the windows in the water
    final night = 1 - daylight;
    if (night > .35 && scene.townLights > .02) {
      final a = (night - .35) / .65;
      final color = dim(const Color(0xFFFFD9A0));
      for (final (c, order) in windows()) {
        if (order >= scene.townLights) continue;
        final mirror = 2 * top - c.dy;
        for (var k = 0; k < 2; k++) {
          final wob = math.sin(t * 1.8 + order * 20 + k) * 1.2;
          paint
            ..strokeWidth = .9
            ..color = color.withValues(alpha: (.18 + .12 * _wave(t, 2, order * 9)) * a * calm);
          canvas.drawLine(
            Offset(c.dx - 1.6 + wob, mirror + k * 2.6),
            Offset(c.dx + 1.6 + wob, mirror + k * 2.6),
            paint,
          );
        }
      }
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

/// An eight-pointed star (two squares, one turned by 45°): the Friday mark.
Path khatam(Offset c, double r) {
  final path = Path();
  for (var k = 0; k < 2; k++) {
    for (var i = 0; i < 4; i++) {
      final a = k * math.pi / 4 + i * math.pi / 2;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
  }
  return path;
}
