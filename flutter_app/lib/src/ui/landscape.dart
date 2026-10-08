import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../logic/prayer.dart';
import 'colors.dart';

/// The land under the full-screen sky: two mountain ranges, a forested ridge, a lake that mirrors them, and the
/// dark shore with a few pines.
///
/// The mountains are built as faces: from every peak a ridge runs down to its foot, and each face is lit or in
/// shade depending on where the sun is, with gullies in the rock, snow that lies according to the time of year
/// and pink alpenglow at sunrise and sunset. Each range is a step closer and darker, with mist at its foot, so
/// the land has depth. Every colour comes from the sky of the hour.
///
/// Nothing here moves: it is painted only when the light changes (about once a minute), so it costs no battery.
///
/// Laid out in a box at the bottom of the screen: x from 0 to 400 across, v from 0 (the top of the box) to 100
/// (the bottom of the screen); the mountains rise above the box.
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

  /// Where the sun and the moon go down: behind the mountains.
  static double horizonFor(Size size) => size.height - heightFor(size) * 1.12;

  // ---------- Light and colour ----------

  /// 1 in full daylight, about .1 in the depth of the night.
  late final double daylight = (1 - pal.stars * .9).clamp(0.0, 1.0);

  /// How strongly the low sun colours the land (around sunrise and sunset).
  late final double warm = () {
    final sp = scene.sunProgress;
    final edge = math.min(sp.abs(), (sp - 1).abs());
    return _smooth(1 - edge / .2);
  }();

  /// Where the sun is across the screen (0–1); the faces turned towards it are lit.
  late final double sunX = .5 - .42 * math.cos(math.pi * scene.sunProgress.clamp(0.0, 1.0));

  /// −1 when the light comes from the left (morning), 1 from the right (afternoon); the moon at night.
  late final double _lightFrom = () {
    final night = scene.sunProgress < 0 || scene.sunProgress > 1;
    if (night && scene.moon.up) return (scene.moon.progress.clamp(0.0, 1.0) - .5) * 2;
    return (sunX - .5) * 2;
  }();

  /// How strong the light and shade are: by day, and softly under a bright moon.
  late final double _contrast = math.max(daylight, scene.moon.up ? .35 * scene.moon.illumination : 0);

  late final Color _haze = pal.colors.last;
  late final Color _sky = pal.colors[pal.colors.length ~/ 2];

  double get snow => scene.snow;

  /// The darkest colour of the land: the night sky's blue after dark, the season's colour (deep and quiet) by
  /// day, paler under snow and a little lighter under a bright moon.
  late final Color _ground = () {
    final night = Color.lerp(pal.colors.first, const Color(0xFF02040C), .55)!;
    final day = Color.lerp(Color(scene.season), const Color(0xFF1C2626), .58)!;
    var g = Color.lerp(night, day, daylight)!;
    g = Color.lerp(g, Color.lerp(const Color(0xFF2A3344), const Color(0xFFB8C4D0), daylight)!, snow * .5)!;
    if (scene.moon.up) g = Color.lerp(g, const Color(0xFF8C9AB8), .08 * scene.moon.illumination * (1 - daylight))!;
    return g;
  }();

  /// Rock: a cool grey, taking the light of the hour.
  late final Color _rock = Color.lerp(const Color(0xFF5E6470), _ground, .55)!;

  /// The colour of a layer: [t] 0 is the horizon's haze, 1 the darkest ground.
  Color _layer(Color base, double t) {
    var c = Color.lerp(_haze, base, t)!;
    if (scene.tintStrength > 0) c = Color.lerp(c, Color(scene.tint), scene.tintStrength * .35)!;
    return c;
  }

  /// Snow on the high peaks: through most of the year, only on the tops in summer.
  double get _peakSnow => math.max(snow, .12 + .7 * math.pow(scene.cold, 1.3));

  /// [c] lit ([f] > 0) or shaded ([f] < 0); the lit side warms at sunrise and sunset.
  Color _shade(Color c, double f) {
    final k = f * _contrast;
    if (k >= 0) {
      final lit = Color.lerp(c, Colors.white, .16 * k)!;
      return warm > 0 ? Color.lerp(lit, pal.sun, .22 * warm * k)! : lit;
    }
    return Color.lerp(c, const Color(0xFF060814), .30 * -k)!;
  }

  // ---------- Shapes ----------

  /// A ridge line: the main points, with smaller bumps added in between (always the same, from [seed]).
  static List<Offset> _ridge(List<(double, double)> main, int seed, double rough) {
    final rnd = math.Random(seed);
    var pts = [for (final (X, v) in main) Offset(X, v)];
    var amp = rough;
    for (var pass = 0; pass < 3; pass++) {
      final next = <Offset>[];
      for (var i = 0; i < pts.length - 1; i++) {
        final a = pts[i], b = pts[i + 1];
        next
          ..add(a)
          ..add(
            Offset(
              (a.dx + b.dx) / 2 + (rnd.nextDouble() - .5) * (b.dx - a.dx) * .2,
              (a.dy + b.dy) / 2 + (rnd.nextDouble() - .5) * amp,
            ),
          );
      }
      next.add(pts.last);
      pts = next;
      amp *= .55;
    }
    return pts;
  }

  static const List<(double, double)> _farMain = [
    (-12, -2),
    (14, -14),
    (34, -6),
    (58, -26),
    (74, -16),
    (92, -22),
    (116, -44),
    (132, -30),
    (146, -36),
    (168, -12),
    (190, -4),
    (214, -16),
    (236, -8),
    (258, -2),
    (280, -18),
    (300, -30),
    (322, -48),
    (340, -32),
    (356, -38),
    (380, -14),
    (412, -20),
  ];

  static const List<(double, double)> _midMain = [
    (-12, 16),
    (22, 4),
    (44, 12),
    (70, -2),
    (96, 10),
    (124, 6),
    (150, 16),
    (180, 8),
    (206, 18),
    (236, 4),
    (262, -6),
    (284, 6),
    (310, 14),
    (340, 2),
    (368, 10),
    (392, 0),
    (412, 8),
  ];

  static final List<Offset> _far = _ridge(_farMain, 11, 9);
  static final List<Offset> _mid = _ridge(_midMain, 23, 7);

  /// Where the water begins, and where the shore in front begins.
  static const double _waterV = 50;

  // ---------- Painting ----------

  void paint(Canvas canvas) {
    // the land above the water, recorded once so the lake can mirror it
    final recorder = ui.PictureRecorder();
    final land = Canvas(recorder);
    _range(land, _far, depth: .36, foot: 34, rock: _rock, snowLine: _lerp(-38, 4, _peakSnow), seed: 3);
    _mist(land, 34, .5);
    _range(
      land,
      _mid,
      depth: .56,
      foot: 46,
      rock: Color.lerp(_rock, _ground, .5)!,
      snowLine: _lerp(-14, 30, snow * .9),
      seed: 7,
    );
    _mist(land, 44, .38);
    _forest(land);
    final picture = recorder.endRecording();

    canvas.drawPicture(picture);
    _lake(canvas, picture);
    _shore(canvas);
    picture.dispose();
  }

  /// A mountain range: faces from each peak down to its foot, lit or shaded, with gullies and snow.
  void _range(
    Canvas canvas,
    List<Offset> ridge, {
    required double depth,
    required double foot,
    required Color rock,
    required double snowLine,
    required int seed,
  }) {
    Offset p(Offset q) => Offset(x(q.dx), y(q.dy));
    final base = _layer(rock, depth + .2);
    final outline = Path()..moveTo(p(ridge.first).dx, p(ridge.first).dy);
    for (final q in ridge.skip(1)) {
      outline.lineTo(p(q).dx, p(q).dy);
    }
    outline
      ..lineTo(x(ridge.last.dx), y(foot + 8))
      ..lineTo(x(ridge.first.dx), y(foot + 8))
      ..close();
    canvas.drawPath(outline, Paint()..color = dim(base));

    // the main peaks and the valleys between them
    final marks = <int>[0];
    for (var i = 1; i < ridge.length - 1; i++) {
      final isPeak = ridge[i].dy < ridge[i - 1].dy && ridge[i].dy < ridge[i + 1].dy;
      final isValley = ridge[i].dy > ridge[i - 1].dy && ridge[i].dy > ridge[i + 1].dy;
      // only the bigger ones: a peak must stand a little above its neighbours two steps away
      if ((isPeak || isValley) && i - marks.last >= 3) marks.add(i);
    }
    marks.add(ridge.length - 1);

    final rnd = math.Random(seed);
    // from every peak and every valley a spur runs down to the foot: a jagged line, slanting a little; the faces
    // on either side share it, so they meet without gaps
    final spurs = <int, List<Offset>>{};
    for (final k in marks) {
      final top = p(ridge[k]);
      final bottom = y(foot + 8);
      final slant = (rnd.nextDouble() - .5) * 14 * u;
      final pts = <Offset>[top];
      const n = 5;
      for (var j = 1; j <= n; j++) {
        final f = j / n;
        final jitter = j == n ? 0.0 : (rnd.nextDouble() - .5) * 3.2 * u;
        pts.add(Offset(top.dx + slant * f + jitter, top.dy + (bottom - top.dy) * f));
      }
      spurs[k] = pts;
    }
    final snowColorLit = Color.lerp(
      _layer(const Color(0xFFF4F7FB), depth + .45),
      const Color(0xFFFFC2B0),
      warm * daylight * .4,
    )!;
    final snowColorShade = _layer(const Color(0xFFB4C0D6), depth + .4);

    canvas.save();
    canvas.clipPath(outline);
    for (var m = 0; m < marks.length - 1; m++) {
      final a = marks[m], b = marks[m + 1];
      final goingDown = ridge[b].dy > ridge[a].dy; // from a peak down to a valley
      // a face going down to the right looks right
      final facing = (goingDown ? 1.0 : -1.0) * _lightFrom.sign * math.min(1, _lightFrom.abs() * 1.6 + .25);
      final peak = goingDown ? ridge[a] : ridge[b];
      // along the ridge, down the next spur, and back up this one
      final face = Path()..moveTo(p(ridge[a]).dx, p(ridge[a]).dy);
      for (var i = a + 1; i <= b; i++) {
        face.lineTo(p(ridge[i]).dx, p(ridge[i]).dy);
      }
      for (final q in spurs[b]!.skip(1)) {
        face.lineTo(q.dx, q.dy);
      }
      for (final q in spurs[a]!.reversed) {
        face.lineTo(q.dx, q.dy);
      }
      face.close();
      final lit = _shade(base, facing);
      final top = y(peak.dy), bottom = y(foot + 8);
      canvas.drawPath(
        face,
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, top), Offset(0, bottom), [
            dim(lit),
            dim(Color.lerp(lit, _layer(_ground, depth + .3), .55)!),
          ]),
      );

      canvas.save();
      canvas.clipPath(face);
      // snow above the snow line, with a ragged edge that reaches lower in the gullies
      if (snowLine > peak.dy - 2) {
        final edge = Path()..moveTo(x(ridge[a].dx - 2), y(-70));
        final steps = math.max(4, (ridge[b].dx - ridge[a].dx) ~/ 2.5);
        for (var s = 0; s <= steps; s++) {
          final X = ridge[a].dx + (ridge[b].dx - ridge[a].dx) * s / steps;
          final drop = (rnd.nextDouble() - .3) * 6 + 3 * math.sin(X * .7);
          edge.lineTo(x(X), y(snowLine + drop));
        }
        edge
          ..lineTo(x(ridge[b].dx + 2), y(-70))
          ..close();
        final snowColor = facing >= 0 ? snowColorLit : snowColorShade;
        canvas.drawPath(edge, Paint()..color = dim(_shade(snowColor, facing * .6)).withValues(alpha: .92));
      }
      // gullies: thin lines from the ridge down the face
      final gully = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6
        ..color = Colors.black.withValues(alpha: .03 + .05 * _contrast);
      for (var i = a + 2; i < b - 1; i += 4) {
        final q = p(ridge[i]);
        final len = (y(foot) - q.dy) * (.25 + rnd.nextDouble() * .3);
        final lean = (goingDown ? -1 : 1) * len * (.3 + rnd.nextDouble() * .3);
        canvas.drawPath(
          Path()
            ..moveTo(q.dx, q.dy + 1)
            ..quadraticBezierTo(q.dx + lean * .3, q.dy + len * .5, q.dx + lean, q.dy + len),
          gully,
        );
      }
      canvas.restore();
    }
    canvas.restore();

    // the sunlit edge of the ridge at sunrise and sunset (alpenglow)
    if (warm * daylight > .05) {
      final rim = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeJoin = StrokeJoin.round
        ..color = dim(Color.lerp(pal.sun, Colors.white, .3)!).withValues(alpha: .45 * warm * daylight * (1 - depth));
      canvas.drawPath(Path()..addPolygon([for (final q in ridge) p(q)], false), rim);
    }
  }

  /// Mist lying at the foot of a range.
  void _mist(Canvas canvas, double v, double strength) {
    final mist = dim(Color.lerp(_haze, Colors.white, .1 * daylight)!);
    final a = strength * (.55 + .45 * daylight) + .25 * scene.mist;
    canvas.drawRect(
      Rect.fromLTRB(0, y(v - 16), w, y(v + 6)),
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, y(v - 16)), Offset(0, y(v + 2)), [
          mist.withValues(alpha: 0),
          mist.withValues(alpha: a.clamp(0.0, .85)),
        ]),
    );
  }

  /// The forested ridge above the water: the tips of countless pines.
  void _forest(Canvas canvas) {
    final rnd = math.Random(41);
    final color = dim(_layer(Color.lerp(_ground, const Color(0xFF0F2018), .3 * daylight)!, .78));
    final path = Path()..moveTo(x(-10), y(_waterV + 2));
    for (var X = -10.0; X <= 410; X += 1.6) {
      final ground = 42 + 3.2 * math.sin(X * .021 + 1) + 1.6 * math.sin(X * .067);
      final tip = 1.2 + rnd.nextDouble() * 2.6;
      path
        ..lineTo(x(X), y(ground))
        ..lineTo(x(X + .8), y(ground - tip));
    }
    path
      ..lineTo(x(410), y(_waterV + 2))
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, y(36)), Offset(0, y(_waterV)), [
          color,
          Color.lerp(color, Colors.black, .25)!,
        ]),
    );
    // snow on the trees in winter
    if (snow > .3) {
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, y(38)), Offset(0, y(46)), [
            dim(Colors.white).withValues(alpha: .35 * snow * (.4 + .6 * daylight)),
            dim(Colors.white).withValues(alpha: 0),
          ]),
      );
    }
  }

  late final double _frozen = _smooth((snow - .6) / .3);

  /// The lake: the land and the sky mirrored and softened, the sun's or the moon's path of light, and a few
  /// still ripples. Pale and white when it freezes.
  void _lake(Canvas canvas, ui.Picture land) {
    final waterY = y(_waterV);
    final water = Rect.fromLTRB(0, waterY, w, h);
    // the sky, upside down
    canvas.drawRect(
      water,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, waterY), Offset(0, h), [
          dim(Color.lerp(_haze, _ground, .25)!),
          dim(Color.lerp(_sky, _ground, .55)!),
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

    if (_frozen < .9) {
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
        ..color = dim(Color.lerp(_haze, Colors.white, .5)!).withValues(alpha: .05 + .05 * daylight);
      for (var i = 0; i < 10; i++) {
        final yy = waterY + 2 + rnd.nextDouble() * (h - waterY) * .6;
        final xx = rnd.nextDouble() * w;
        final len = 20 + rnd.nextDouble() * 50;
        canvas.drawLine(Offset(xx, yy), Offset(xx + len, yy), ripple);
      }
    }
    // ice
    if (_frozen > .02) {
      canvas.drawRect(
        water,
        Paint()..color = dim(Color.lerp(_haze, const Color(0xFFE4ECF4), .6)!).withValues(alpha: .7 * _frozen),
      );
    }
    // a fine bright line where the water meets the land
    canvas.drawRect(
      Rect.fromLTRB(0, waterY - .3, w, waterY + .7),
      Paint()..color = Colors.white.withValues(alpha: .05 + .08 * daylight),
    );
  }

  /// The shore in front, with a few pines on each side.
  void _shore(Canvas canvas) {
    final color = dim(_layer(Color.lerp(_ground, Colors.black, .35)!, .95));
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

double _lerp(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);

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
