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
  Landscape({required this.size, required this.pal, required this.scene, required this.dim});

  final Size size;
  final SkyPalette pal;
  final SkyScene scene;

  /// The dark theme's dimming of a colour.
  final Color Function(Color) dim;

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
    canvas.clipRect(water);
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

    // the path of light under the sun, or the moon
    void lightPath(double atX, Color color, double strength) {
      if (strength <= .02) return;
      final c = Offset(atX, waterY);
      canvas.drawRect(
        Rect.fromLTRB(atX - 40, waterY, atX + 40, h),
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            90,
            [color.withValues(alpha: .35 * strength), color.withValues(alpha: 0)],
            const [0, 1],
            TileMode.clamp,
            (Matrix4.identity()
                  ..translateByDouble(c.dx, c.dy, 0, 1)
                  ..scaleByDouble(.35, 1, 1, 1)
                  ..translateByDouble(-c.dx, -c.dy, 0, 1))
                .storage,
          ),
      );
      final r = math.Random(5);
      final dash = Paint()
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 16; i++) {
        final f = (i + .5) / 16;
        final yy = waterY + 3 + f * (h - waterY) * .8;
        final spread = 4 + 22 * f;
        final xx = atX + (r.nextDouble() - .5) * 2 * spread;
        final len = 3 + 12 * f * r.nextDouble();
        dash.color = color.withValues(alpha: strength * (.7 - .5 * f) * (.4 + .6 * r.nextDouble()));
        canvas.drawLine(Offset(xx - len / 2, yy), Offset(xx + len / 2, yy), dash);
      }
    }

    final sp = scene.sunProgress;
    if (sp > -.02 && sp < 1.02) lightPath(sunX * w, dim(Color.lerp(pal.sun, Colors.white, .2)!), .8 * daylight);
    final moon = scene.moon;
    if (moon.up && moon.illumination > .05 && daylight < .5) {
      final mx = (.5 - .42 * math.cos(math.pi * moon.progress.clamp(0.0, 1.0))) * w;
      lightPath(mx, dim(const Color(0xFFF2EEDC)), .6 * moon.illumination * (1 - daylight));
    }
    // still ripples
    final rnd = math.Random(17);
    final ripple = Paint()
      ..strokeWidth = .7
      ..color = dim(Color.lerp(_air, Colors.white, .5)!).withValues(alpha: .05 + .05 * daylight);
    for (var i = 0; i < 10; i++) {
      final yy = waterY + 2 + rnd.nextDouble() * (h - waterY) * .6;
      final xx = rnd.nextDouble() * w;
      final len = 20 + rnd.nextDouble() * 50;
      canvas.drawLine(Offset(xx, yy), Offset(xx + len, yy), ripple);
    }
    // a fine bright line where the water meets the land
    canvas.drawRect(
      Rect.fromLTRB(0, waterY - .3, w, waterY + .7),
      Paint()..color = Colors.white.withValues(alpha: .05 + .08 * daylight),
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
  }

  // ---------- The big tree ----------

  /// Where the big tree stands on the left shore, across (0–400).
  static const double _treeX = 70;

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

    canvas.save();
    canvas.translate(x(_treeX), y(83.6));
    canvas.scale(u * .8);

    // the trunk and the branches (all that shows in winter)
    final bark = dim(Color.lerp(shore, const Color(0xFF5B4838), .45 * _day)!);
    // the foot: roots spreading into the ground (every shape wound the same way, so none cuts a hole in another)
    final wood = Path()
      ..moveTo(-10, 3)
      ..quadraticBezierTo(-4, .5, -3.3, -9)
      ..lineTo(3.3, -9)
      ..quadraticBezierTo(4, .5, 10, 3)
      ..close();
    for (final (a, b, wa, wb) in tree.limbs) {
      final d = b - a;
      final n = Offset(-d.dy, d.dx) / d.distance;
      wood
        ..addPolygon([a - n * (wa / 2), b - n * (wb / 2), b + n * (wb / 2), a + n * (wa / 2)], true)
        ..addOval(Rect.fromCircle(center: b, radius: wb / 2));
    }
    // darker down the trunk, into the shore at its foot
    canvas.drawPath(
      wood,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bark, bark, dim(shore)],
          stops: const [0, .72, 1],
        ).createShader(const Rect.fromLTRB(-60, -130, 60, 2)),
    );

    // the crown: the leaves still on the tree at this time of the year, in small clusters with the sky between
    final leaves = scene.treeLeaves;
    if (leaves > 0) {
      final grow = .75 + .25 * leaves;
      final shown = [
        for (final l in tree.leaves)
          if (l.$3 < leaves * 1.02) (l.$1, l.$2 * grow, l.$4, l.$5),
      ];
      if (shown.isNotEmpty) {
        final leaf = Color(scene.treeLeaf);
        final body = Color.lerp(shore, leaf, .6 * _day)!;
        final crown = Path();
        var box = Rect.fromCircle(center: shown.first.$1, radius: shown.first.$2);
        for (final (c, r, _, _) in shown) {
          final o = Rect.fromCircle(center: c, radius: r);
          crown.addOval(o);
          box = box.expandToInclude(o);
        }
        canvas.drawPath(
          crown,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment(side, -1),
              end: Alignment(-side, 1),
              colors: [dim(body), dim(Color.lerp(body, shore, .55)!)],
            ).createShader(box),
        );
        // the leaves facing the light catch it, those turned away and underneath sink into shade
        final bright = Color.lerp(Color.lerp(shore, leaf, .9 * _day + .1)!, glow, .28 + .2 * warm)!;
        final tones = [
          Color.lerp(bright, const Color(0xFFF0D060), .14)!,
          bright,
          Color.lerp(bright, const Color(0xFFB84A2A), .12)!,
        ];
        final paths = List.generate(6, (_) => Path());
        final shade = Path();
        for (final (c, r, tone, rel) in shown) {
          final facing = rel.dx * side * .7 - rel.dy * .7;
          if (facing < -.25) {
            shade.addOval(Rect.fromCircle(center: c + Offset(-side * .2, .25) * r, radius: r * .75));
          } else if (facing > .05) {
            paths[(facing > .4 ? 3 : 0) + (tone < -.35 ? 0 : (tone > .35 ? 2 : 1))].addOval(
              Rect.fromCircle(center: c + Offset(side * .3, -.35) * r, radius: r * .62),
            );
          }
        }
        canvas.drawPath(shade, Paint()..color = dim(shore).withValues(alpha: .3 * _day));
        if (lit > .02) {
          for (var i = 0; i < 6; i++) {
            canvas.drawPath(paths[i], Paint()..color = dim(tones[i % 3]).withValues(alpha: lit * (i < 3 ? .4 : .72)));
          }
        }
      }
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
final ({List<(Offset, Offset, double, double)> limbs, List<(Offset, double, double, double, Offset)> leaves}) _bigTree =
    () {
      final rnd = math.Random(5150);
      final limbs = <(Offset, Offset, double, double)>[];
      final clumps = <(Offset, double, double, double)>[];
      void grow(Offset from, double angle, double len, double width, int depth) {
        final bend = (rnd.nextDouble() - .5) * .22;
        final to = from + Offset(math.cos(angle + bend), math.sin(angle + bend)) * len;
        final end = math.max(width * .64, .5);
        limbs.add((from, to, width, end));
        if (depth >= 2) {
          clumps.add((to, 7 + rnd.nextDouble() * 4, rnd.nextDouble(), rnd.nextDouble() * 2 - 1));
          if (depth == 3) {
            clumps.add((Offset.lerp(from, to, .45)!, 6.5 + rnd.nextDouble() * 3, rnd.nextDouble(), rnd.nextDouble() * 2 - 1));
          }
        }
        if (depth == 4) return;
        final n = depth == 0 ? 3 : 2 + (rnd.nextDouble() < .4 ? 1 : 0);
        for (var i = 0; i < n; i++) {
          var a = angle + (i - (n - 1) / 2) * (depth == 0 ? .6 : .48) + (rnd.nextDouble() - .5) * .22;
          a += (-math.pi / 2 - a) * .22; // the higher, the more towards the sky
          grow(to, a, len * (.64 + rnd.nextDouble() * .1), end, depth + 1);
        }
      }

      grow(Offset.zero, -math.pi / 2 + .05, 46, 6.4, 0);
      // two lower limbs, out to each side
      grow(const Offset(.4, -30), -math.pi / 2 - .95, 21, 3.2, 2);
      grow(const Offset(.9, -36), -math.pi / 2 + .9, 19, 3, 2);
      // and the inside of the crown, so it is full in summer
      final rest = clumps.map((c) => c.$1).toList();
      final mid = rest.reduce((a, b) => a + b) / rest.length.toDouble();
      for (var i = 0; i < 7; i++) {
        final a = i / 7 * 2 * math.pi;
        clumps.insert(0, (
          mid + Offset(math.cos(a) * 14, math.sin(a) * 9 + 4),
          10 + rnd.nextDouble() * 3,
          rnd.nextDouble(),
          rnd.nextDouble() * 2 - 1,
        ));
      }
      // each clump: a dozen small clusters of leaves, loosely around it, with the sky showing between them
      final centre = clumps.map((c) => c.$1).reduce((a, b) => a + b) / clumps.length.toDouble();
      final far = clumps.map((c) => (c.$1 - centre).distance + c.$2).reduce(math.max);
      final leaves = <(Offset, double, double, double, Offset)>[];
      for (final (c, r, order, tone) in clumps) {
        for (var k = 0; k < 12; k++) {
          final a = rnd.nextDouble() * 2 * math.pi;
          final p = c + Offset(math.cos(a), math.sin(a) * .85) * (math.sqrt(rnd.nextDouble()) * r * .85);
          leaves.add((
            p,
            r * (.24 + rnd.nextDouble() * .16),
            (order + (rnd.nextDouble() - .5) * .16).clamp(0.0, 1.0),
            tone + (rnd.nextDouble() - .5) * .7,
            (p - centre) / far,
          ));
        }
      }
      return (limbs: limbs, leaves: leaves);
    }();

