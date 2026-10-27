import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../logic/prayer.dart';
import 'colors.dart';

/// The land under the full-screen sky, as it looks from a valley: a far mountain range, low and pale with
/// distance, wooded ridges one in front of the other with mist lying between them, a lake that mirrors them, and
/// the dark shore with a few pines.
///
/// Like a photograph, the land is silhouettes, each nearer one a little darker, and all of its light comes from
/// the sky of the moment: almost black at night under a faint glow over the horizon, the mist and the far range
/// lit a little by a bright moon, blue with distance by day with the season only on the near woods, and the haze
/// warmed on the side of the low sun at sunrise and sunset. No snow and no ice: the calendar cannot know the
/// weather.
///
/// Nothing here moves: it is painted into a still picture of the sky (StillSky, in sky.dart), again only when the
/// light changes (about once a minute).
///
/// Laid out in a box at the bottom of the screen: x from 0 to 400 across, v from 0 (the top of the box) to 100
/// (the bottom of the screen); the far range rises a little above the box.
class Landscape {
  Landscape({
    required this.size,
    required this.pal,
    required this.scene,
    required this.dim,
    this.t = 0.0,
  });

  final Size size;
  final SkyPalette pal;
  final SkyScene scene;

  /// The dark theme's dimming of a colour.
  final Color Function(Color) dim;

  /// Animation time in seconds for water shimmer, dynamic reflections, surface ripples, and tree breeze.
  final double t;

  double get w => size.width;
  double get h => size.height;

  /// Height of the box.
  static double heightFor(Size size) => math.min(.23 * size.height, 196.0);

  late final double boxH = heightFor(size);
  double get top => h - boxH;

  /// One unit of the box, the same across and up.
  double get u => boxH / 100;
  double x(double X) => X / 400 * w;
  double y(double v) => top + v * boxH / 100;

  /// Where the sun and the moon go down: behind the far range, a little below its summits.
  static double horizonFor(Size size) => size.height - heightFor(size) * 1.08;

  // ---------- Light and colour ----------

  /// 1 in full daylight, about .1 in the depth of the night.
  late final double daylight = (1 - pal.stars * .9).clamp(0.0, 1.0);

  /// 1 by day, 0 at night.
  late final double _day = (1 - pal.stars).clamp(0.0, 1.0);

  /// How strongly the low sun colours the haze (around sunrise and sunset).
  late final double warm = () {
    final sp = scene.sunProgress;
    final edge = math.min(sp.abs(), (sp - 1).abs());
    return _smooth(1 - edge / .2);
  }();

  /// Where the sun is across the screen (0–1).
  late final double sunX = .5 - .42 * math.cos(math.pi * scene.sunProgress.clamp(0.0, 1.0));

  /// How much the moon lights the land: only when the sun is down and the moon is up, by how much of it is lit
  /// and how high it stands.
  late final double moonlight = () {
    final m = scene.moon;
    if (!m.up) return 0.0;
    return m.illumination * _smooth(3 * math.sin(math.pi * m.progress.clamp(0.0, 1.0))) * pal.stars;
  }();

  /// The air between here and the far range: the sky low over the horizon, with the hour's tint.
  late final Color _air = () {
    var c = Color.lerp(pal.colors.last, pal.horizonHaze, .3 + .3 * moonlight)!;
    if (scene.tintStrength > 0) c = Color.lerp(c, Color(scene.tint), scene.tintStrength * .35)!;
    return c;
  }();

  /// The darkest the land gets, close by: near black at night, a little lifted by a bright moon, the season's
  /// colour (deep and quiet) on the woods by day.
  late final Color _ink = () {
    final night = Color.lerp(pal.colors.first, const Color(0xFF010207), .6)!;
    final day = Color.lerp(Color(scene.season), const Color(0xFF151C1E), .6)!;
    return Color.lerp(Color.lerp(night, day, _day)!, const Color(0xFF3A4458), .25 * moonlight)!;
  }();

  /// Snow close by: white by day, grey-blue at night, a little brighter under the moon.
  late final Color _snow = Color.lerp(_ink, const Color(0xFFF2F5FA), (.3 + .62 * _day + .3 * moonlight).clamp(0.0, .95))!;

  /// Bare rock far away: blue-grey by day, as dark as the rest at night.
  late final Color _rock = Color.lerp(_ink, const Color(0xFF4A5566), .55 * _day)!;

  /// The mist in the valleys: grey-blue at night (brighter under the moon), white by day.
  late final Color _mist = Color.lerp(
    _air,
    Color.lerp(const Color(0xFF8F99B0), const Color(0xFFF1F3F6), _day)!,
    .55 + .25 * moonlight,
  )!;

  /// How thick the mist lies: always a little in the valleys, more at night and most on misty mornings.
  late final double _mistDepth = (.55 + .2 * moonlight - .25 * _day + .35 * scene.mist).clamp(0.0, .85);

  /// A layer [near] (0 the air – 1 the darkest ground) of [base].
  Color _layer(Color base, double near) => Color.lerp(_air, base, near)!;

  // ---------- Shapes ----------

  /// A ridge line, the same on every start: v at every 2 units across (x = 0, 2 … 400). Summits (x, rise,
  /// half-width, shape: 1 pointed … 3 broad) stand on the [base] line, and midpoint displacement breaks the line up
  /// like real rock or woods, [rough] units at most, more of it on the high parts.
  static List<double> _ridgeLine(
    double base,
    List<(double, double, double, double)> summits, {
    required int seed,
    required double rough,
  }) {
    const n = 256;
    final rnd = math.Random(seed);
    final f = List<double>.filled(n + 1, 0);
    f[0] = rnd.nextDouble();
    f[n] = rnd.nextDouble();
    var scale = 1.0;
    for (var step = n; step > 1; step ~/= 2) {
      final half = step ~/ 2;
      for (var i = half; i < n; i += step) {
        f[i] = (f[i - half] + f[i + half]) / 2 + (rnd.nextDouble() - .5) * scale;
      }
      scale *= .68;
    }
    final lo = f.reduce(math.min), hi = f.reduce(math.max);
    final highest = summits.fold(0.0, (m, s) => math.max(m, s.$2));
    return List.generate(201, (i) {
      final X = i * 2.0;
      var rise = 0.0;
      for (final (sx, sr, hw, shape) in summits) {
        rise = math.max(rise, sr * math.exp(-math.pow((X - sx).abs() / hw, shape)));
      }
      final k = (i / 200 * n).floor();
      final noise = (f[k] - lo) / (hi - lo) - .5;
      return base - rise - rough * noise * (.35 + .65 * rise / highest);
    });
  }

  /// The far range: a long massif on the left, the main summit right of the middle with a shoulder, and a pair
  /// of sharper peaks on the right.
  static final List<double> _far = _ridgeLine(
    -5,
    const [
      (0, 8, 34, 2),
      (42, 11, 26, 2),
      (98, 15, 46, 3),
      (86, 18, 12, 1.5),
      (150, 11, 24, 2),
      (206, 8, 30, 2.4),
      (236, 17, 20, 1.6),
      (264, 29, 30, 1.3),
      (304, 14, 18, 1.8),
      (348, 17, 16, 1.7),
      (373, 20, 18, 1.6),
      (400, 15, 22, 1.8),
    ],
    seed: 11,
    rough: 8,
  );

  /// The wooded ridges in front, nearly level: (the ridge line, the seed of its treetops). Just two, with the mist
  /// between them: more layers looked drawn rather than seen.
  static final List<(List<double>, int)> _woods = [
    (
      _ridgeLine(
        12,
        const [(20, 4, 50, 1.8), (110, 7, 45, 1.6), (200, 2.5, 40, 2), (290, 6, 55, 1.7), (380, 8, 45, 1.6)],
        seed: 23,
        rough: 2.5,
      ),
      31,
    ),
    // the nearest hills rise on both sides and dip to the lake in the middle
    (
      _ridgeLine(
        44,
        const [(0, 14, 80, 1.6), (150, 3, 40, 2), (260, 2, 40, 2), (400, 16, 90, 1.6)],
        seed: 51,
        rough: 2.4,
      ),
      59,
    ),
  ];

  /// Where the water begins.
  static const double _waterV = 50;

  /// The outline of a ridge, reaching down under the water's edge (the nearer ones cover the rest); with
  /// [trees], a soft fuzz of treetops along its top.
  Path _outline(List<double> line, {int? trees}) {
    const bottom = _waterV + 2;
    final path = Path()..moveTo(x(-4), y(bottom));
    if (trees == null) {
      for (var i = 0; i < line.length; i++) {
        path.lineTo(x(i * 2.0), y(line[i]));
      }
    } else {
      final rnd = math.Random(trees);
      for (var X = -4.0; X <= 404; X += 1.1) {
        final t = (X / 2).clamp(0.0, 199.999);
        final i = t.floor();
        final v = line[i] + (line[i + 1] - line[i]) * (t - i);
        // the woods: treetops in loose clumps
        final clump = .55 + .45 * math.sin(X * .19 + trees);
        path.lineTo(x(X), y(v - 1.3 * clump * math.pow(rnd.nextDouble(), 1.6)));
      }
    }
    path
      ..lineTo(x(404), y(bottom))
      ..close();
    return path;
  }

  /// The highest point of a ridge (the smallest v).
  static double _peak(List<double> line) => line.reduce(math.min);

  /// The average height of a ridge.
  static double _mean(List<double> line) => line.reduce((a, b) => a + b) / line.length;

  // ---------- Painting ----------

  void paint(Canvas canvas) {
    // the land above the water, recorded once so the lake can mirror it
    final recorder = ui.PictureRecorder();
    final land = Canvas(recorder);
    _farRange(land);
    for (var i = 0; i < _woods.length; i++) {
      _wood(land, i);
    }
    final picture = recorder.endRecording();

    canvas.drawPicture(picture);
    _lake(canvas, picture);
    _shore(canvas);
    _tree(canvas);
    picture.dispose();
  }

  /// The far range: one silhouette, pale with distance, its foot lost in the mist; the side towards the sun a
  /// little lighter by day; the haze around it warm when the sun is low.
  void _farRange(Canvas canvas) {
    // it fades into the mist where the first wooded ridge stands in front of it
    final next = _mean(_woods.first.$1);
    final outline = _outline(_far);
    final c = _layer(_rock, .62);
    canvas.drawPath(
      outline,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, y(_peak(_far))),
          Offset(0, y(next + 2)),
          [dim(c), dim(c), dim(Color.lerp(c, _mist, _mistDepth)!)],
          const [0, .45, 1],
        ),
    );
    // by day the side facing the sun is a little lighter and the other a little darker; at noon, neither
    final side = (sunX - .5) * 2 * _day;
    if (side.abs() > .05) {
      final lit = Colors.white.withValues(alpha: .045 * side.abs());
      final shade = Colors.black.withValues(alpha: .05 * side.abs());
      final (left, right) = side < 0 ? (lit, shade) : (shade, lit);
      canvas.drawPath(
        outline,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(w, 0),
            [left, left.withValues(alpha: 0), right.withValues(alpha: 0), right],
            const [0, .45, .55, 1],
          ),
      );
    }
    // the low sun catches the edge of the ridge (only that: a glow over the range washed it out)
    final glow = warm * (.4 + .6 * daylight);
    if (glow > .02) {
      final sun = dim(Color.lerp(pal.sun, Colors.white, .15)!);
      canvas.drawPath(
        Path()..addPolygon([for (var i = 0; i < _far.length; i++) Offset(x(i * 2.0), y(_far[i]))], false),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..strokeJoin = StrokeJoin.round
          ..color = sun.withValues(alpha: .22 * glow),
      );
    }
    _mistBand(canvas, next + 1, 1);
  }

  /// A wooded ridge: dark along its treetops, fading down into the mist in front of it.
  void _wood(Canvas canvas, int i) {
    final (line, trees) = _woods[i];
    final last = i == _woods.length - 1;
    // each fades into the mist where the next one stands in front of it; the nearest hills reach the water
    final bottom = last ? _waterV : _mean(_woods[i + 1].$1) + 1;
    final c = _layer(_ink, .74 + .1 * i);
    final foot = last ? Color.lerp(c, _mist, _mistDepth * .3)! : Color.lerp(c, _mist, _mistDepth * (.95 - .15 * i))!;
    canvas.drawPath(
      _outline(line, trees: trees),
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, y(_peak(line) - 1.5)), Offset(0, y(bottom)), [
          dim(c),
          dim(c),
          dim(foot),
        ], last ? const [0, .6, 1] : const [0, .2, 1]),
    );
    _mistBand(canvas, bottom, last ? .4 : .9 - .2 * i);
  }

  /// A soft band of mist lying at [v], thickest at the bottom.
  void _mistBand(Canvas canvas, double v, double strength) {
    final a = (_mistDepth * strength * .6).clamp(0.0, .7);
    if (a <= .01) return;
    final mist = dim(_mist);
    canvas.drawRect(
      Rect.fromLTRB(0, y(v - 9), w, y(v + 2)),
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, y(v - 9)), Offset(0, y(v + 1)), [
          mist.withValues(alpha: 0),
          mist.withValues(alpha: a),
        ]),
    );
  }

  /// The lake: the land and the sky mirrored and softened, the sun's or the moon's path of light, and a few
  /// still ripples.
  void _lake(Canvas canvas, ui.Picture land) {
    final waterY = y(_waterV);
    final water = Rect.fromLTRB(0, waterY, w, h);
    canvas.save();
    canvas.clipRect(water);
    // the sky, upside down
    canvas.drawRect(
      water,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, waterY), Offset(0, h), [
          dim(Color.lerp(_air, _ink, .35)!),
          dim(Color.lerp(pal.colors[pal.colors.length ~/ 2], _ink, .6)!),
        ]),
    );
    // the land, mirrored and softened
    canvas.save();
    canvas.saveLayer(water, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: .8, sigmaY: 1.6));
    canvas.translate(0, 2 * waterY);
    canvas.scale(1, -1);
    canvas.drawPicture(land);
    canvas.restore();
    canvas.restore();
    // the water is darker and a little blue
    canvas.drawRect(
      water,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, waterY), Offset(0, h), [
          dim(const Color(0xFF0A1A2A)).withValues(alpha: .22 + .1 * (1 - daylight)),
          dim(const Color(0xFF050B14)).withValues(alpha: .5),
        ]),
    );

    // The path of light under the sun or the moon, with dynamic reflection undulations and scintillating dashes
    void lightPath(double atX, Color color, double strength, {required bool isSun}) {
      if (strength <= .02) return;
      final c = Offset(atX, waterY);

      // Dynamic breathing of the radial reflection beam
      final breath = 1.0 + 0.08 * math.sin(t * 1.5 + (isSun ? 0.0 : 1.7));
      final beamReach = 95.0 * breath;
      final beamWidth = 42.0 * breath;

      canvas.drawRect(
        Rect.fromLTRB(atX - beamWidth, waterY, atX + beamWidth, h),
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            beamReach,
            [color.withValues(alpha: (.36 + .06 * math.sin(t * 2.0)) * strength), color.withValues(alpha: 0)],
            const [0, 1],
            TileMode.clamp,
            (Matrix4.identity()
                  ..translateByDouble(c.dx, c.dy, 0, 1)
                  ..scaleByDouble(.36 * breath, 1, 1, 1)
                  ..translateByDouble(-c.dx, -c.dy, 0, 1))
                .storage,
          ),
      );

      // Scintillating reflection dashes dancing across surface micro-waves
      const dashCount = 24;
      final dashPaint = Paint()
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round;

      for (var i = 0; i < dashCount; i++) {
        final f = (i + .5) / dashCount;
        final yy = waterY + 3.0 + math.pow(f, 0.95) * (h - waterY) * .86;
        final spread = 4.0 + 26.0 * f;

        // Deterministic pseudo-random seed per dash index
        final seed1 = ((math.sin(i * 127.1) * 43758.5453).abs() % 1.0);
        final seed2 = ((math.sin(i * 311.7) * 43758.5453).abs() % 1.0);

        // Gentle wave oscillation + drifting perturbation
        final waveX = math.sin(t * 2.2 + i * 1.4) * (1.6 + 3.2 * f) +
            math.sin(t * 1.1 + i * 0.7) * 1.8;
        final xx = atX + (seed1 - .5) * 2 * spread * 0.75 + waveX;

        // Length breathes organically
        final baseLen = 3.5 + 14.0 * f * seed2;
        final len = baseLen * (0.8 + 0.35 * (0.5 + 0.5 * math.sin(t * 2.7 + i * 2.1)));

        // Scintillating brightness
        final twinkle = 0.5 + 0.5 * math.sin(t * 3.3 + i * 2.5);
        final alpha = (strength * (.75 - .45 * f) * (.35 + .65 * twinkle)).clamp(0.0, 1.0);

        dashPaint.strokeWidth = 0.9 + 0.5 * f;
        dashPaint.color = color.withValues(alpha: alpha);
        canvas.drawLine(Offset(xx - len / 2, yy), Offset(xx + len / 2, yy), dashPaint);

        // Specular highlight glints on crests
        if (i % 3 == 0) {
          final glintTwinkle = (math.sin(t * 4.2 + i * 3.1) - 0.5).clamp(0.0, 0.5) * 2.0;
          if (glintTwinkle > 0.1) {
            final glintPaint = Paint()
              ..strokeWidth = 1.0
              ..strokeCap = StrokeCap.round
              ..color = Colors.white.withValues(alpha: (alpha * 1.3 * glintTwinkle).clamp(0.0, 1.0));
            final glintLen = math.max(2.0, len * 0.45);
            canvas.drawLine(Offset(xx - glintLen / 2, yy), Offset(xx + glintLen / 2, yy), glintPaint);
          }
        }
      }
    }

    final sp = scene.sunProgress;
    if (sp > -.02 && sp < 1.02) {
      Color sunReflectColor = dim(Color.lerp(pal.sun, Colors.white, .2)!);
      if (warm > .2) {
        sunReflectColor = Color.lerp(sunReflectColor, const Color(0xFFFF9E44), warm * .6)!;
      }
      lightPath(sunX * w, sunReflectColor, .8 * daylight, isSun: true);
    }
    final moon = scene.moon;
    if (moon.up && moon.illumination > .05 && daylight < .5) {
      final mx = moon.x * w;
      lightPath(mx, dim(const Color(0xFFF2EEDC)), .65 * moon.illumination * (1 - daylight), isSun: false);
    }

    // Gentle horizontal shimmer lines across the water surface
    const shimmerCount = 18;
    final shimmerPaint = Paint()
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;

    for (var k = 0; k < shimmerCount; k++) {
      final kf = (k + 0.5) / shimmerCount;
      final yy = waterY + 2.5 + kf * (h - waterY) * 0.92;
      final baseLen = 22.0 + 60.0 * kf;
      final speed = 4.0 + 7.0 * kf; // perspective speed gradient

      final seed = ((math.sin(k * 213.3) * 43758.5453).abs() % 1.0);
      final cycle = ((seed * w + t * speed) % (w + baseLen * 2)) - baseLen;

      // Gentle horizontal sway
      final waveOffset = math.sin(t * 1.5 + k * 1.8) * 8.0;
      final xx = cycle + waveOffset;

      // Glimmering brightness: slow undulating pulse
      final pulse = 0.5 + 0.5 * math.sin(t * 1.7 + k * 1.6);
      final alpha = ((0.03 + 0.055 * daylight + 0.025 * moonlight) * pulse).clamp(0.0, 0.16);

      if (alpha > 0.005) {
        shimmerPaint.strokeWidth = 0.7 + 0.4 * kf;
        shimmerPaint.color = dim(Color.lerp(_air, Colors.white, 0.65)!).withValues(alpha: alpha);
        canvas.drawLine(Offset(xx, yy), Offset(xx + baseLen, yy), shimmerPaint);
      }
    }

    // Slow-drifting surface ripples with subtle wave curves and relief
    const rippleCount = 14;
    for (var j = 0; j < rippleCount; j++) {
      final seedA = ((math.sin(j * 93.1) * 43758.5453).abs() % 1.0);
      final seedB = ((math.sin(j * 179.3) * 43758.5453).abs() % 1.0);
      final jf = (j + 0.5) / rippleCount;
      final yy = waterY + 3.0 + jf * (h - waterY) * 0.78;
      final rLen = 35.0 + seedA * 70.0;
      final rSpeed = 6.0 + 10.0 * jf; // slow, serene drift
      final rx = ((seedB * w + t * rSpeed) % (w + rLen * 2)) - rLen;

      final waveSway = math.sin(t * 1.1 + j * 1.7) * 4.0;
      final currentX = rx + waveSway;

      // Gentle crest curve using quadratic bezier
      final crestHeight = 0.7 * (1.0 - jf * 0.25);
      final path = Path()
        ..moveTo(currentX, yy)
        ..quadraticBezierTo(currentX + rLen * 0.5, yy - crestHeight, currentX + rLen, yy);

      final rPulse = 0.6 + 0.4 * math.sin(t * 1.3 + j * 2.1);
      final crestAlpha = ((0.045 + 0.065 * daylight + 0.025 * moonlight) * rPulse).clamp(0.0, 0.16);

      // Crest highlight
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..strokeCap = StrokeCap.round
          ..color = dim(Color.lerp(_air, Colors.white, 0.7)!).withValues(alpha: crestAlpha),
      );

      // Subtle shadow trough line immediately underneath for realistic depth
      final shadowPath = Path()
        ..moveTo(currentX + 2.0, yy + 0.9)
        ..quadraticBezierTo(currentX + rLen * 0.5, yy + 0.9 + crestHeight * 0.6, currentX + rLen - 2.0, yy + 0.9);
      canvas.drawPath(
        shadowPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..strokeCap = StrokeCap.round
          ..color = dim(const Color(0xFF020712)).withValues(alpha: (0.07 * rPulse).clamp(0.0, 0.12)),
      );
    }

    canvas.restore();

    // a fine bright line where the water meets the land
    canvas.drawRect(
      Rect.fromLTRB(0, waterY - .3, w, waterY + .7),
      Paint()..color = Colors.white.withValues(alpha: .06 + .09 * daylight),
    );
  }

  /// The shore in front, with a few pines on each side.
  void _shore(Canvas canvas) {
    final color = dim(_layer(Color.lerp(_ink, Colors.black, .35)!, .96));
    final path = Path()..moveTo(x(-10), y(84));
    path
      ..cubicTo(x(60), y(80), x(120), y(87), x(200), y(86))
      ..cubicTo(x(280), y(85), x(340), y(79), x(410), y(83))
      ..lineTo(x(410), y(104))
      ..lineTo(x(-10), y(104))
      ..close();
    // pines: (x, height in units)
    for (final (X, ht) in const [
      (6.0, 26.0),
      (16.0, 34.0),
      (27.0, 22.0),
      (36.0, 15.0),
      (368.0, 18.0),
      (382.0, 30.0),
      (395.0, 24.0),
    ]) {
      final baseV = X < 200 ? 84 - (X / 60) * 4 : 79 + (X - 340) / 70 * 4;
      path.addPath(_pine(Offset(x(X), y(baseV + 1)), ht * u * .6, ht * u * .16), Offset.zero);
    }
    canvas.drawPath(path, Paint()..color = color);
    // in winter, snow along the bank
    final snow = scene.treeSnow;
    if (snow > .02) {
      final bank = Path()
        ..moveTo(x(-10), y(84))
        ..cubicTo(x(60), y(80), x(120), y(87), x(200), y(86))
        ..cubicTo(x(280), y(85), x(340), y(79), x(410), y(83));
      canvas.drawPath(
        bank,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 * u * snow
          ..color = dim(_snow).withValues(alpha: .9),
      );
    }
  }

  // ---------- The big tree ----------

  /// Where the big tree stands on the left shore, across (0–400).
  static const double _treeX = 70;

/// Adds an individual botanical leaf shape to [path].
///
/// Features a tapered base, curved organic blade margins, and a sharp pointed apex.
/// Supports drawing only the left or right facet of the blade for 3D creased lighting.
void _addLeaf(
  Path path,
  Offset center,
  double len,
  double wid,
  double angle, {
  bool leftFacetOnly = false,
  bool rightFacetOnly = false,
}) {
  final cosA = math.cos(angle);
  final sinA = math.sin(angle);
  final ux = cosA, uy = sinA;
  final nx = -sinA, ny = cosA;

  final bx = center.dx - ux * (len * 0.5);
  final by = center.dy - uy * (len * 0.5);
  final tx = center.dx + ux * (len * 0.5);
  final ty = center.dy + uy * (len * 0.5);

  final c1x = center.dx - ux * (len * 0.12) + nx * (wid * 0.55);
  final c1y = center.dy - uy * (len * 0.12) + ny * (wid * 0.55);
  final c2x = center.dx + ux * (len * 0.22) + nx * (wid * 0.48);
  final c2y = center.dy + uy * (len * 0.22) + ny * (wid * 0.48);

  final c3x = center.dx + ux * (len * 0.22) - nx * (wid * 0.48);
  final c3y = center.dy + uy * (len * 0.22) - ny * (wid * 0.48);
  final c4x = center.dx - ux * (len * 0.12) - nx * (wid * 0.55);
  final c4y = center.dy - uy * (len * 0.12) - ny * (wid * 0.55);

  if (leftFacetOnly) {
    path
      ..moveTo(bx, by)
      ..cubicTo(c1x, c1y, c2x, c2y, tx, ty)
      ..lineTo(bx, by)
      ..close();
  } else if (rightFacetOnly) {
    path
      ..moveTo(bx, by)
      ..lineTo(tx, ty)
      ..cubicTo(c3x, c3y, c4x, c4y, bx, by)
      ..close();
  } else {
    path
      ..moveTo(bx, by)
      ..cubicTo(c1x, c1y, c2x, c2y, tx, ty)
      ..cubicTo(c3x, c3y, c4x, c4y, bx, by)
      ..close();
  }
}

/// Adds a fine central midrib vein line for the leaf.
void _addLeafMidrib(Path path, Offset center, double len, double angle) {
  final cosA = math.cos(angle);
  final sinA = math.sin(angle);
  final bx = center.dx - cosA * (len * 0.46);
  final by = center.dy - sinA * (len * 0.46);
  final tx = center.dx + cosA * (len * 0.42);
  final ty = center.dy + sinA * (len * 0.42);
  path
    ..moveTo(bx, by)
    ..lineTo(tx, ty);
}

  /// The big tree on the left shore, its foot in the shore: a dark shape against the sky at night (a little lit by
  /// a bright moon), in the leaves of the season by day — bare in winter, budding in March, fresh green in April,
  /// deep green in summer, gold and orange in October, thinning in November — lit on the side of the sun, warm
  /// when the sun is low. Painted with the rest of the land, only when the light changes.
  void _tree(Canvas canvas) {
    final tree = _bigTree;
    final shore = _layer(Color.lerp(_ink, Colors.black, .35)!, .96);
    // where the light comes from: the sun by day, the moon at night, across (-1 left … 1 right of the tree)
    final treeAt = _treeX / 400;
    final lightAt = _day > .3 ? sunX : (scene.moon.up ? scene.moon.x : treeAt);
    final side = ((lightAt - treeAt) * 4).clamp(-1.0, 1.0);
    final glow = _day > .3
        ? Color.lerp(const Color(0xFFFFF3DC), const Color(0xFFFFB067), warm)!
        : const Color(0xFFB9C7E8);
    final lit = (_day * (.55 + .2 * warm) + .35 * moonlight).clamp(0.0, 1.0);

    // Dynamic wind effect: soothing natural breeze
    final wind = (math.sin(t * 1.05) * 0.7 + math.sin(t * 1.85 + 0.8) * 0.3) * (0.85 + 0.15 * math.sin(t * 0.35));
    Offset limbSway(Offset pt, int depth) =>
        pt + Offset(wind * math.pow(depth / 5.0, 1.7) * 2.8, -wind.abs() * 0.3 * (depth / 5.0));
    Offset leafSway(Offset pt, Offset rel, int layer) {
      final k = layer == 2 ? 1.0 : (layer == 1 ? 0.6 : 0.25);
      final phase = (pt.dx * 0.19 + pt.dy * 0.27);
      return pt + Offset(
        wind * 2.5 * k + math.sin(t * 2.1 + phase) * 0.9 * k,
        -wind.abs() * 0.4 * k + math.cos(t * 1.7 + phase) * 0.4 * k,
      );
    }

    canvas.save();
    canvas.translate(x(_treeX), y(83.6));
    canvas.scale(u * .8);

    // the ground under it: the fallen leaves of autumn (individual tapered leaves)
    final fallen = scene.treeFallen;
    if (fallen > .02) {
      final leaf = Color(scene.treeLeaf);
      final looks = [
        Color.lerp(shore, leaf, .25 + .6 * _day)!,
        Color.lerp(shore, const Color(0xFFB5552C), .25 + .55 * _day)!,
        Color.lerp(shore, const Color(0xFFD9A030), .25 + .55 * _day)!,
      ];
      final heaps = [Path(), Path(), Path()];
      for (final (p, lLen, lWid, lAngle, order, tone) in tree.fallen) {
        if (order < fallen) {
          _addLeaf(heaps[tone], p, lLen, lWid, lAngle);
        }
      }
      for (var i = 0; i < 3; i++) {
        canvas.drawPath(heaps[i], Paint()..color = dim(looks[i]));
      }
    }

    final leaves = scene.treeLeaves;
    final leaf = Color(scene.treeLeaf);
    final grow = .75 + .25 * leaves;

    // --- Layer 0: Deep interior shadow canopy (behind branches, small detailed leaves) ---
    if (leaves > 0) {
      final deepCanopy = Path();
      for (final (c, len, wid, angle, order, _, rel, layer) in tree.leaves) {
        if (layer == 0 && order < leaves * 1.02) {
          final p = leafSway(c, rel, layer);
          _addLeaf(deepCanopy, p, len * grow, wid * grow, angle);
        }
      }
      canvas.drawPath(deepCanopy, Paint()..color = dim(Color.lerp(shore, leaf, .35 * _day)!));
    }

    // --- Detailed, tapering branches ---
    final bark = dim(Color.lerp(shore, const Color(0xFF524032), .45 * _day)!);
    final wood = Path();

    // Natural root flares spreading smoothly into the shore bank
    wood
      ..moveTo(-12, 3)
      ..cubicTo(-6, 2, -4, -4, -3.8, -12)
      ..lineTo(3.8, -12)
      ..cubicTo(4, -4, 6, 2, 12, 3)
      ..close();

    for (final (rawA, rawB, rawC, wa, wb, depth) in tree.limbs) {
      final a = limbSway(rawA, math.max(0, depth - 1));
      final b = limbSway(rawB, depth);
      final c = limbSway(rawC, depth);

      final d1 = b - a;
      final dist1 = d1.distance > 0.001 ? d1.distance : 1.0;
      final n1 = Offset(-d1.dy, d1.dx) / dist1;

      final d2 = b - c;
      final dist2 = d2.distance > 0.001 ? d2.distance : 1.0;
      final n2 = Offset(-d2.dy, d2.dx) / dist2;

      final wMid = (wa + wb) * 0.52;

      // Smooth tapering branch contour with curved bezier edges
      wood
        ..moveTo(a.dx - n1.dx * (wa / 2), a.dy - n1.dy * (wa / 2))
        ..quadraticBezierTo(c.dx - n1.dx * (wMid / 2), c.dy - n1.dy * (wMid / 2), b.dx - n2.dx * (wb / 2), b.dy - n2.dy * (wb / 2))
        ..quadraticBezierTo(b.dx + d2.dx / dist2 * (wb * 0.7), b.dy + d2.dy / dist2 * (wb * 0.7), b.dx + n2.dx * (wb / 2), b.dy + n2.dy * (wb / 2))
        ..quadraticBezierTo(c.dx + n1.dx * (wMid / 2), c.dy + n1.dy * (wMid / 2), a.dx + n1.dx * (wa / 2), a.dy + n1.dy * (wa / 2))
        ..close();
    }

    // Branch shading: darker down trunk, into shore
    canvas.drawPath(
      wood,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(side * 0.5, -1),
          end: Alignment(-side * 0.5, 1),
          colors: [
            Color.lerp(bark, glow, .12 * lit)!,
            bark,
            dim(shore),
          ],
          stops: const [0, .68, 1],
        ).createShader(const Rect.fromLTRB(-65, -135, 65, 5)),
    );

    // Snow on branches in winter
    final snow = scene.treeSnow;
    if (snow > .02) {
      final caps = Path();
      for (var (rawA, rawB, _, wa, wb, depth) in tree.limbs) {
        final a = limbSway(rawA, math.max(0, depth - 1));
        final b = limbSway(rawB, depth);
        final d = b - a;
        final level = d.dx.abs() / (d.distance > 0.001 ? d.distance : 1.0);
        if (level < .2) continue;
        final ta = wa * (.5 + .5 * level) * snow, tb = wb * (.5 + .5 * level) * snow;
        final ua = Offset(0, -wa * .42), ub = Offset(0, -wb * .42);
        caps.addPolygon([a + ua, b + ub, b + ub - Offset(0, tb), a + ua - Offset(0, ta)], true);
      }
      canvas.drawPath(caps, Paint()..color = dim(_snow));
    }

    // --- Layers 1 & 2: Mid-canopy and Foreground leaf clusters with dynamic rim lighting ---
    if (leaves > 0) {
      final body = Color.lerp(shore, leaf, .62 * _day)!;
      final midCrown = Path();
      var box = Rect.fromCenter(center: tree.leaves.first.$1, width: 24, height: 24);

      // Layer 1: Mid-canopy body (individual detailed leaves)
      for (final (c, len, wid, angle, order, _, rel, layer) in tree.leaves) {
        if (layer == 1 && order < leaves * 1.02) {
          final p = leafSway(c, rel, layer);
          final lLen = len * grow;
          final lWid = wid * grow;
          _addLeaf(midCrown, p, lLen, lWid, angle);
          box = box.expandToInclude(Rect.fromCenter(center: p, width: lLen * 2, height: lLen * 2));
        }
      }
      if (!midCrown.getBounds().isEmpty) {
        canvas.drawPath(
          midCrown,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment(side, -1),
              end: Alignment(-side, 1),
              colors: [dim(body), dim(Color.lerp(body, shore, .55)!)],
            ).createShader(box),
        );
      }

      // Layer 2: Foreground clusters with tonal variation, faceted leaves, midrib veins, and rim lighting
      final bright = Color.lerp(Color.lerp(shore, leaf, .9 * _day + .1)!, glow, .28 + .2 * warm)!;
      final tones = [
        Color.lerp(bright, const Color(0xFFF0D060), .16)!,
        bright,
        Color.lerp(bright, const Color(0xFFB84A2A), .14)!,
      ];
      final litLeftFacets = List.generate(3, (_) => Path());
      final litRightFacets = List.generate(3, (_) => Path());
      final shadeLeaves = Path();
      final midribs = Path();
      final rimPath = Path();

      // Dynamic rim lighting color calculation reflecting sun/moon and season
      final Color rimColor;
      if (_day > .3) {
        if (warm > .25) {
          final warmSunset = Color.lerp(const Color(0xFFFF8C42), leaf, 0.25)!;
          rimColor = Color.lerp(const Color(0xFFFFD166), warmSunset, warm * .75)!;
        } else {
          final seasonalGlint = Color.lerp(leaf, Colors.white, 0.45)!;
          rimColor = Color.lerp(const Color(0xFFFFFDE7), seasonalGlint, .4)!;
        }
      } else {
        rimColor = Color.lerp(const Color(0xFFD6E2F8), Colors.white, 0.2 * moonlight)!;
      }
      final sunProgress = scene.sunProgress.clamp(0.0, 1.0);
      final elevation = _day > .3
          ? math.sin(sunProgress * math.pi)
          : (scene.moon.up ? math.sin(scene.moon.progress.clamp(0.0, 1.0) * math.pi) : 0.4);
      final rimStrength = (_day * (.55 + .4 * warm) + .4 * moonlight).clamp(0.0, 1.0);

      for (final (c, len, wid, angle, order, tone, rel, layer) in tree.leaves) {
        if (layer == 2 && order < leaves * 1.02) {
          final p = leafSway(c, rel, layer);
          final lLen = len * grow;
          final lWid = wid * grow;
          final flutter = math.sin(t * 3.2 + p.dx * 0.45) * 0.12 * (wind > 0.01 ? 1.0 : 0.2);
          final lAngle = angle + flutter;

          final facing = rel.dx * side * .75 - rel.dy * .65;

          if (facing < -.22) {
            _addLeaf(shadeLeaves, p, lLen, lWid, lAngle);
          } else {
            final tIndex = (tone < -.35 ? 0 : (tone > .35 ? 2 : 1));
            // Faceted leaf: sun-facing half is brighter, opposite half has body tone
            _addLeaf(litLeftFacets[tIndex], p, lLen, lWid, lAngle, leftFacetOnly: true);
            _addLeaf(litRightFacets[tIndex], p, lLen, lWid, lAngle, rightFacetOnly: true);
            _addLeafMidrib(midribs, p, lLen, lAngle);
          }

          // Rim lighting highlight along outer edges facing sun/moon
          final rimFacing = (rel.dx * side * 0.8 + (1.0 - elevation) * 0.3 - rel.dy * 0.4).clamp(-1.0, 1.0);
          if (rimFacing > 0.08) {
            final rimOffset = Offset(side * 0.35, -0.4 * elevation - 0.2) * (lLen * 0.25);
            _addLeaf(rimPath, p + rimOffset, lLen * 0.88, lWid * 0.7, lAngle);
          }
        }
      }

      // Draw shaded leaves
      canvas.drawPath(shadeLeaves, Paint()..color = dim(shore).withValues(alpha: .32 * _day));

      // Draw lit leaves with faceted 3D depth
      if (lit > .02) {
        for (var i = 0; i < 3; i++) {
          final tone = tones[i];
          final sunlitHalf = dim(tone).withValues(alpha: lit * 0.88);
          final shadeHalf = dim(Color.lerp(tone, shore, 0.25)!).withValues(alpha: lit * 0.72);
          canvas.drawPath(litLeftFacets[i], Paint()..color = sunlitHalf);
          canvas.drawPath(litRightFacets[i], Paint()..color = shadeHalf);
        }
        // Draw fine leaf midrib veins
        canvas.drawPath(
          midribs,
          Paint()
            ..color = dim(Color.lerp(shore, const Color(0xFF1E3516), 0.5)!).withValues(alpha: lit * 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.35
            ..strokeCap = StrokeCap.round,
        );
      }

      // Draw rim lighting
      if (rimStrength > 0.05) {
        canvas.drawPath(
          rimPath,
          Paint()
            ..color = dim(rimColor).withValues(alpha: (rimStrength * 0.72).clamp(0.0, 0.95)),
        );
      }
    }

    // Spring: Blossoms swaying gently on twigs
    final blossom = scene.treeBlossom;
    if (blossom > .02) {
      final seen = (.25 + .7 * _day + .25 * moonlight).clamp(0.0, 1.0);
      final white = dim(Color.lerp(shore, const Color(0xFFFFF7FA), seen)!);
      final pink = dim(Color.lerp(shore, const Color(0xFFF4A9C4), seen)!);
      final w = Path(), p = Path();
      for (final (c, r, order, rose, depth) in tree.blossoms) {
        if (order < blossom) {
          final pt = limbSway(c, depth);
          (rose ? p : w).addOval(Rect.fromCircle(center: pt, radius: r));
        }
      }
      canvas.drawPath(p, Paint()..color = pink);
      canvas.drawPath(w, Paint()..color = white);
    }

    // Summer: Ripe fruit
    final fruit = scene.treeFruit;
    if (fruit > .02 && leaves > .5) {
      final red = dim(Color.lerp(shore, const Color(0xFFC9302C), .2 + .7 * _day)!);
      final shine = dim(Color.lerp(shore, const Color(0xFFFF9A84), .15 + .6 * _day)!);
      final f = Path(), s = Path();
      for (final (c, r, order) in tree.fruits) {
        if (order < fruit) {
          final pt = c + Offset(wind * 1.5, 0);
          f.addOval(Rect.fromCircle(center: pt, radius: r));
          s.addOval(Rect.fromCircle(center: pt + Offset(-r * .3, -r * .35), radius: r * .35));
        }
      }
      canvas.drawPath(f, Paint()..color = red);
      canvas.drawPath(s, Paint()..color = shine);
    }

    canvas.restore();
  }

  /// A pine: tiers of branches narrowing to the top.
  static Path _pine(Offset base, double height, double width) {
    final path = Path();
    const tiers = 5;
    for (var i = 0; i < tiers; i++) {
      final t0 = i / tiers, t1 = (i + 1.6) / tiers;
      final yb = base.dy - height * t0 * .92;
      final yt = base.dy - height * math.min(1, t1);
      final half = width * (1 - t0 * .78);
      path.addPolygon([Offset(base.dx - half, yb), Offset(base.dx, yt), Offset(base.dx + half, yb)], true);
    }
    path.addRect(Rect.fromLTRB(base.dx - width * .08, base.dy - height * .1, base.dx + width * .08, base.dy + 2));
    return path;
  }
}

double _smooth(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

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

/// The big tree, in units of the landscape box with its foot at (0, 0) and up negative, the same on every start:
/// its limbs (from, to, width at each end) and the clumps of leaves on them (centre, radius, when in the year it is
/// in leaf 0–1: the lowest values are the last to fall and the first to come, and a tone -1 … 1 for a little
/// variety in colour).
final ({
  List<(Offset, Offset, Offset, double, double, int)> limbs,
  List<(Offset, double, double, double, double, double, Offset, int)> leaves,
  List<(Offset, double, double, bool, int)> blossoms,
  List<(Offset, double, double)> fruits,
  List<(Offset, double, double, double, double, int)> fallen,
})
_bigTree = () {
  final rnd = math.Random(5150);
  final limbs = <(Offset, Offset, Offset, double, double, int)>[];
  final clumps = <(Offset, double, double, double, int)>[];

  void grow(Offset from, double angle, double len, double width, int depth) {
    final bend = (rnd.nextDouble() - .5) * .22;
    final to = from + Offset(math.cos(angle + bend), math.sin(angle + bend)) * len;
    // Curved control point for graceful organic arching
    final mid = Offset.lerp(from, to, 0.5)!;
    final normal = Offset(-math.sin(angle), math.cos(angle));
    final ctrl = mid + normal * ((rnd.nextDouble() - .5) * len * 0.22);
    final end = math.max(width * .62, .48);
    limbs.add((from, to, ctrl, width, end, depth));

    if (depth >= 2) {
      clumps.add((to, 7.5 + rnd.nextDouble() * 4.5, rnd.nextDouble(), rnd.nextDouble() * 2 - 1, depth));
      if (depth == 3) {
        clumps.add((Offset.lerp(from, to, .45)!, 6.5 + rnd.nextDouble() * 3.5, rnd.nextDouble(), rnd.nextDouble() * 2 - 1, depth));
      }
    }
    if (depth == 4) return;
    final n = depth == 0 ? 3 : 2 + (rnd.nextDouble() < .4 ? 1 : 0);
    for (var i = 0; i < n; i++) {
      var a = angle + (i - (n - 1) / 2) * (depth == 0 ? .58 : .46) + (rnd.nextDouble() - .5) * .22;
      a += (-math.pi / 2 - a) * .22; // naturally arch towards the sky
      grow(to, a, len * (.64 + rnd.nextDouble() * .1), end, depth + 1);
    }
  }

  grow(Offset.zero, -math.pi / 2 + .04, 46, 7.2, 0);
  // two lower limbs, out to each side
  grow(const Offset(.4, -30), -math.pi / 2 - .95, 22, 3.4, 2);
  grow(const Offset(.9, -36), -math.pi / 2 + .9, 20, 3.2, 2);

  // inside of crown for summer fullness
  final rest = clumps.map((c) => c.$1).toList();
  final mid = rest.reduce((a, b) => a + b) / rest.length.toDouble();
  for (var i = 0; i < 7; i++) {
    final a = i / 7 * 2 * math.pi;
    clumps.insert(0, (
      mid + Offset(math.cos(a) * 14, math.sin(a) * 9 + 4),
      10.5 + rnd.nextDouble() * 3.5,
      rnd.nextDouble(),
      rnd.nextDouble() * 2 - 1,
      2,
    ));
  }

  final centre = clumps.map((c) => c.$1).reduce((a, b) => a + b) / clumps.length.toDouble();
  final far = clumps.map((c) => (c.$1 - centre).distance + c.$2).reduce(math.max);
  final leaves = <(Offset, double, double, double, double, double, Offset, int)>[];

  for (final (c, r, order, tone, _) in clumps) {
    // Botanical leaves arranged in natural radiating sprigs
    // Layer 0: Deep interior silhouette shadow (behind branches)
    for (var k = 0; k < 8; k++) {
      final a = rnd.nextDouble() * 2 * math.pi;
      final dist = math.sqrt(rnd.nextDouble()) * r * 0.72;
      final p = c + Offset(math.cos(a), math.sin(a) * 0.85) * dist;
      final outAngle = (p - c).distance > 0.1 ? (p - c).direction : -math.pi / 2;
      final leafAngle = outAngle + (rnd.nextDouble() - 0.5) * 0.65;
      final lLen = 3.2 + rnd.nextDouble() * 1.2;
      final lWid = lLen * (0.42 + rnd.nextDouble() * 0.1);
      leaves.add((
        p,
        lLen,
        lWid,
        leafAngle,
        (order + (rnd.nextDouble() - .5) * .14).clamp(0.0, 1.0),
        tone + (rnd.nextDouble() - .5) * .5,
        (p - centre) / far,
        0, // layer 0: deep shadow
      ));
    }
    // Layer 1: Mid-canopy volume leaves
    for (var k = 0; k < 12; k++) {
      final a = rnd.nextDouble() * 2 * math.pi;
      final dist = math.sqrt(rnd.nextDouble()) * r * 0.88;
      final p = c + Offset(math.cos(a), math.sin(a) * 0.88) * dist;
      final outAngle = (p - c).distance > 0.1 ? (p - c).direction : -math.pi / 2;
      final leafAngle = outAngle + (rnd.nextDouble() - 0.5) * 0.65;
      final lLen = 3.4 + rnd.nextDouble() * 1.3;
      final lWid = lLen * (0.43 + rnd.nextDouble() * 0.1);
      leaves.add((
        p,
        lLen,
        lWid,
        leafAngle,
        (order + (rnd.nextDouble() - .5) * .16).clamp(0.0, 1.0),
        tone + (rnd.nextDouble() - .5) * .6,
        (p - centre) / far,
        1, // layer 1: mid canopy
      ));
    }
    // Layer 2: Outer foreground leaves (reaching out into the air, rim lighting, detailed facets)
    for (var k = 0; k < 14; k++) {
      final a = rnd.nextDouble() * 2 * math.pi;
      final dist = (0.35 + 0.65 * math.sqrt(rnd.nextDouble())) * r * 1.04;
      final p = c + Offset(math.cos(a), math.sin(a) * 0.9) * dist;
      final outAngle = (p - c).distance > 0.1 ? (p - c).direction : -math.pi / 2;
      final leafAngle = outAngle + (rnd.nextDouble() - 0.5) * 0.6;
      final lLen = 3.6 + rnd.nextDouble() * 1.4;
      final lWid = lLen * (0.44 + rnd.nextDouble() * 0.08);
      leaves.add((
        p,
        lLen,
        lWid,
        leafAngle,
        (order + (rnd.nextDouble() - .5) * .16).clamp(0.0, 1.0),
        tone + (rnd.nextDouble() - .5) * .7,
        (p - centre) / far,
        2, // layer 2: foreground & rim
      ));
    }
  }

  // Also add small sprigs of leaves directly along the smaller branches (depth >= 2)
  for (final (a, b, _, _, wb, depth) in limbs) {
    if (depth < 2 || wb > 2.8) continue;
    final limbDir = (b - a).direction;
    for (var k = 0; k < 4; k++) {
      final t = 0.3 + rnd.nextDouble() * 0.65;
      final pt = Offset.lerp(a, b, t)!;
      final sideSign = (k % 2 == 0) ? 1.0 : -1.0;
      final offsetDist = 1.2 + rnd.nextDouble() * 2.5;
      final normal = Offset(-math.sin(limbDir), math.cos(limbDir));
      final p = pt + normal * (sideSign * offsetDist);
      final leafAngle = limbDir + sideSign * (0.45 + rnd.nextDouble() * 0.4);
      final lLen = 3.2 + rnd.nextDouble() * 1.0;
      final lWid = lLen * 0.44;
      leaves.add((
        p,
        lLen,
        lWid,
        leafAngle,
        rnd.nextDouble(),
        (rnd.nextDouble() - 0.5) * 0.8,
        (p - centre) / far,
        (rnd.nextDouble() < 0.6 ? 2 : 1),
      ));
    }
  }

  final extra = math.Random(7171);
  final blossoms = <(Offset, double, double, bool, int)>[];
  for (final (c, r, _, _, depth) in clumps) {
    for (var k = 0; k < 8; k++) {
      final a = extra.nextDouble() * 2 * math.pi;
      final p = c + Offset(math.cos(a), math.sin(a)) * (math.sqrt(extra.nextDouble()) * r * 1.05);
      blossoms.add((p, 1.0 + extra.nextDouble() * .9, extra.nextDouble(), extra.nextDouble() < .45, depth));
    }
  }
  for (final (a, b, _, _, wb, depth) in limbs) {
    if (wb > 2) continue;
    for (var k = 0; k < 2; k++) {
      final p = Offset.lerp(a, b, .4 + extra.nextDouble() * .6)!;
      final jitter = Offset((extra.nextDouble() - .5) * 2.4, (extra.nextDouble() - .5) * 2.4);
      blossoms.add((p + jitter, .9 + extra.nextDouble() * .7, extra.nextDouble(), extra.nextDouble() < .45, depth));
    }
  }
  final fruits = <(Offset, double, double)>[];
  for (var k = 0; k < 28; k++) {
    final (c, r, _, _, _) = clumps[extra.nextInt(clumps.length)];
    final a = extra.nextDouble() * 2 * math.pi;
    fruits.add((c + Offset(math.cos(a), math.sin(a)) * (r * .75 * extra.nextDouble()), 1.5 + extra.nextDouble() * .5, extra.nextDouble()));
  }
  final fallen = <(Offset, double, double, double, double, int)>[];
  for (var k = 0; k < 120; k++) {
    final spread = .25 + .75 * extra.nextDouble();
    final p = Offset((extra.nextDouble() * 2 - 1) * 50 * spread, .2 + extra.nextDouble() * 9 * spread);
    final lLen = 2.8 + extra.nextDouble() * 1.2;
    final lWid = lLen * (0.38 + extra.nextDouble() * 0.1);
    final lAngle = (extra.nextDouble() - 0.5) * 0.6; // gentle ground resting tilt
    fallen.add((
      p,
      lLen,
      lWid,
      lAngle,
      extra.nextDouble(),
      extra.nextInt(3),
    ));
  }
  return (limbs: limbs, leaves: leaves, blossoms: blossoms, fruits: fruits, fallen: fallen);
}();

