import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../logic/prayer.dart';
import 'colors.dart';

/// How the sky card is shown.
enum SkyMode {
  /// A rounded card at the top of the page.
  card,

  /// The sky fills the whole screen.
  full,
}

/// Drives the drift of the haze and clouds, the twinkling stars and the turning sun rays.
///
/// Ticks with the screen (vsync), so the sky moves at the display's frame rate, and stops by itself while the
/// app is out of sight. The time keeps counting across [stop] / [start], so nothing jumps when the app returns.
class SkyClock extends ChangeNotifier {
  SkyClock(TickerProvider vsync) {
    _ticker = vsync.createTicker(_onTick);
  }

  late final Ticker _ticker;
  Duration _base = Duration.zero;
  Duration _elapsed = Duration.zero;
  Duration _painted = Duration.zero;

  /// The sky drifts slowly, so about 30 pictures a second look just as smooth as 60 or 120, for a fraction of
  /// the work and the battery. (The swipe-up sheet and the buttons still move at the display's full rate.)
  static const Duration _frame = Duration(microseconds: 31000);

  double get seconds => (_base + _elapsed).inMicroseconds / 1e6;

  void _onTick(Duration elapsed) {
    _elapsed = elapsed;
    if (elapsed - _painted < _frame && elapsed >= _painted) return;
    _painted = elapsed;
    notifyListeners();
  }

  void start() {
    if (!_ticker.isActive) _ticker.start();
  }

  void stop() {
    if (!_ticker.isActive) return;
    _ticker.stop();
    _base += _elapsed;
    _elapsed = Duration.zero;
    _painted = Duration.zero;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

// brightness(.86) saturate(.95): the same skies, a little dimmer at night so they don't glare.
const double _dimS = 0.95, _dimB = 0.86;
const List<double> _dimMatrix = [
  (0.213 + 0.787 * _dimS) * _dimB,
  (0.715 - 0.715 * _dimS) * _dimB,
  (0.072 - 0.072 * _dimS) * _dimB,
  (0.213 - 0.213 * _dimS) * _dimB,
  (0.715 + 0.285 * _dimS) * _dimB,
  (0.072 - 0.072 * _dimS) * _dimB,
  (0.213 - 0.213 * _dimS) * _dimB,
  (0.715 - 0.715 * _dimS) * _dimB,
  (0.072 + 0.928 * _dimS) * _dimB,
];

final ColorFilter _darkFilter = ColorFilter.matrix([
  _dimMatrix[0], _dimMatrix[1], _dimMatrix[2], 0, 0, //
  _dimMatrix[3], _dimMatrix[4], _dimMatrix[5], 0, 0,
  _dimMatrix[6], _dimMatrix[7], _dimMatrix[8], 0, 0,
  0, 0, 0, 1, 0,
]);

/// The dark-theme filter applied to one colour. The filter is linear, so filtering each colour gives the same
/// picture as filtering the whole layer, without the cost of an offscreen layer on every frame.
Color _dim(Color c) {
  final m = _dimMatrix;
  double ch(int i) => (m[i] * c.r + m[i + 1] * c.g + m[i + 2] * c.b).clamp(0.0, 1.0);
  return Color.from(alpha: c.a, red: ch(0), green: ch(3), blue: ch(6));
}

/// The stars of the card: (x %, y %, size).
const List<(double, double, double)> _stars = [
  (8, 14, 1.3),
  (17, 46, 1),
  (27, 22, 1.6),
  (36, 8, 1),
  (44, 38, 1.2),
  (53, 16, 1),
  (61, 30, 1.5),
  (70, 9, 1),
  (79, 42, 1.3),
  (87, 20, 1),
  (94, 34, 1.6),
  (4, 58, 1),
  (31, 62, 1.1),
  (66, 56, 1),
  (91, 64, 1.2),
];

/// A star of the full-screen sky: where it is (0–1), how big, how bright, its tint, and how it twinkles.
class _Star {
  const _Star(this.x, this.y, this.r, this.bright, this.tint, this.period, this.phase, this.depth);

  final double x;
  final double y;

  /// Radius in logical pixels.
  final double r;

  /// Brightness, 0–1.
  final double bright;
  final Color tint;
  final double period;
  final double phase;

  /// How far the star dims at the bottom of its twinkle.
  final double depth;
}

/// The same stars on every start (a fixed seed): mostly tiny and faint, a handful a little brighter,
/// some faintly blue or warm, each twinkling on its own beat. The first [_baseStars] are always there; the rest
/// come out only deep in the night.
const int _baseStars = 170;

final List<_Star> _fieldStars = () {
  final rnd = math.Random(1447);
  const tints = [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFDCE6FF), Color(0xFFFFF1DE)];
  return List<_Star>.generate(_baseStars + 90, (i) {
    final y = math.pow(rnd.nextDouble(), 1.35).toDouble(); // denser towards the top
    final lucky = i < _baseStars && rnd.nextDouble() < .07;
    final bright = lucky ? .8 + rnd.nextDouble() * .2 : .22 + math.pow(rnd.nextDouble(), 2) * .5;
    return _Star(
      rnd.nextDouble(),
      y,
      lucky ? .8 + rnd.nextDouble() * .35 : .35 + rnd.nextDouble() * .4,
      bright,
      tints[rnd.nextInt(tints.length)],
      1.4 + rnd.nextDouble() * 3.6,
      rnd.nextDouble() * 2 * math.pi,
      .4 + rnd.nextDouble() * .5,
    );
  });
}();

/// The faint dust of the Milky Way: (along the band 0–1, across it −1…1, size, brightness).
final List<(double, double, double, double)> _milkyDust = () {
  final rnd = math.Random(786);
  return List.generate(260, (_) {
    // bunched towards the middle of the band
    final across = (rnd.nextDouble() + rnd.nextDouble() + rnd.nextDouble() - 1.5) / 1.5;
    return (rnd.nextDouble(), across, .25 + rnd.nextDouble() * .35, .25 + rnd.nextDouble() * .55);
  });
}();

/// Windows in the villages on the hills, in the hills' own 400 × 60 space: (x, y, warmth, order they go out).
final List<(double, double, double, double)> _windows = () {
  final rnd = math.Random(1912);
  final near = _nearHill(), far = _farHill();
  final out = <(double, double, double, double)>[];
  // a few villages, each a small cluster of windows
  for (final (vx, count) in const [(70.0, 8), (150.0, 7), (232.0, 10), (290.0, 9), (356.0, 7)]) {
    var tries = 0;
    var made = 0;
    while (made < count && tries < 200) {
      tries++;
      final x = vx + (rnd.nextDouble() - .5) * 40;
      // high on the slopes, where they show above the tabs
      final y = 14 + rnd.nextDouble() * 28;
      final p = Offset(x, y);
      // on the slopes, not floating in the air, and not too deep in the dark foot of the hills
      final onNear = near.contains(p) && !near.contains(p.translate(0, -5));
      final onFar = !near.contains(p) && far.contains(p) && !far.contains(p.translate(0, -6));
      if (!onNear && !onFar) continue;
      out.add((x, y, rnd.nextDouble(), rnd.nextDouble()));
      made++;
    }
  }
  return out;
}();

/// Fireflies: (home x, home y, wander speed, phase).
final List<(double, double, double, double)> _fireflies = () {
  final rnd = math.Random(613);
  return List.generate(
    16,
    (_) => (rnd.nextDouble(), .74 + rnd.nextDouble() * .2, .5 + rnd.nextDouble(), rnd.nextDouble() * 2 * math.pi),
  );
}();

Path _farHill() => Path()
  ..moveTo(0, 34)
  ..cubicTo(30, 27, 58, 30, 92, 22)
  ..relativeCubicTo(30, -7, 52, 2, 84, 6)
  ..relativeCubicTo(34, 4, 58, -17, 96, -19)
  ..relativeCubicTo(30, -2, 48, 12, 76, 13)
  ..relativeCubicTo(22, 1, 36, -6, 52, -8)
  ..lineTo(400, 60)
  ..lineTo(0, 60)
  ..close();

Path _nearHill() => Path()
  ..moveTo(0, 46)
  ..relativeCubicTo(36, -7, 66, -2, 104, -9)
  ..relativeCubicTo(40, -7, 70, 6, 112, 5)
  ..relativeCubicTo(40, -1, 64, -12, 102, -12)
  ..relativeCubicTo(34, 0, 58, 8, 82, 6)
  ..lineTo(400, 60)
  ..lineTo(0, 60)
  ..close();

final Path _farHillPath = _farHill();
final Path _nearHillPath = _nearHill();

/// Soft clouds of the full-screen day sky: (height 0–1, size, seconds to cross the screen, start offset).
const List<(double, double, double, double)> _clouds = [
  (.14, 1.0, 150, .10),
  (.30, .75, 115, .62),
  (.44, .55, 95, .35),
];

/// The puffs of one cloud, relative to its centre and size: (dx, dy, radius).
const List<(double, double, double)> _puffs = [
  (-.55, .10, .34),
  (-.22, -.08, .46),
  (.16, -.16, .52),
  (.50, .02, .40),
  (.02, .14, .44),
];

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// A value that goes 0 → 1 → 0 with ease-in-out, like a CSS `alternate` animation.
double _alternate(double seconds, double duration) {
  final cycle = (seconds / duration) % 2.0;
  return Curves.easeInOut.transform(cycle <= 1 ? cycle : 2 - cycle);
}

/// A gentle 0 → 1 → 0 wave with period [period].
double _wave(double seconds, double period, [double phase = 0]) =>
    .5 + .5 * math.sin(seconds / period * 2 * math.pi + phase);

/// Which part of the sky a painter draws. The parts that never move are kept apart from the moving one,
/// so only the moving one is painted again on each frame.
enum SkyLayer {
  /// The gradient of the sky.
  back,

  /// Haze, clouds, stars, shooting stars, sun rays, the sun or the moon.
  motion,

  /// The hills, the shade behind the numbers and the glass sheen.
  front,
}

class SkyPainter extends CustomPainter {
  SkyPainter({
    required this.layer,
    required this.phase,
    required this.orb,
    required this.scene,
    required this.forbidden,
    required this.mode,
    required this.dark,
    required this.radius,
    this.clock,
    this.lift,
  }) : super(repaint: layer == SkyLayer.motion ? Listenable.merge([clock, lift]) : null);

  final SkyLayer layer;
  final SkyPhase phase;
  final OrbState orb;

  /// The Moon and the scenes of the current hour.
  final SkyScene scene;
  final bool forbidden;
  final SkyMode mode;
  final bool dark;
  final double radius;

  /// Null when animations are off.
  final SkyClock? clock;

  /// Full screen: how far the prayer-times sheet is open; the sun or moon rises with the countdown.
  final Animation<double>? lift;

  bool get _full => mode == SkyMode.full;

  Color _k(Color c) => dark ? _dim(c) : c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    final pal = skyPalettes[phase]!;
    switch (layer) {
      case SkyLayer.back:
        canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [for (final c in pal.colors) _k(c)], pal.stops),
        );
        _hourTint(canvas, size);
        if (_full) _milkyWay(canvas, size, pal);
      case SkyLayer.motion:
        final t = clock?.seconds ?? 0.0;
        final live = clock != null;
        _haze(canvas, size, pal, t);
        if (_full) _paintClouds(canvas, size, pal, t);
        _paintStars(canvas, size, pal, t);
        if (_full) _brightStar(canvas, size, t);
        if (_full && live) _shootingStar(canvas, size, pal, t);
        _paintMoon(canvas, size, t);
        _paintSun(canvas, size, pal, t);
        if (_full && live) {
          _birds(canvas, size, t);
          _plane(canvas, size, t);
          _nightPlane(canvas, size, t);
        }
        if (_full) _paintFireflies(canvas, size, t);
      case SkyLayer.front:
        _hills(canvas, size, pal);
        _veil(canvas, size);
        // glass sheen along the top edge
        canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h * .38), [
              _k(const Color(0x29FFFFFF)),
              const Color(0x00FFFFFF),
            ]),
        );
        if (radius > 0) {
          // a 1px highlight inside the top edge
          final rr = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
          final edge = Path.combine(
            PathOperation.difference,
            Path()..addRRect(rr),
            Path()..addRRect(rr.shift(const Offset(0, 1))),
          );
          canvas.drawPath(edge, Paint()..color = const Color(0x38FFFFFF));
        }
    }
  }

  /// Two soft clouds of colour that drift and turn slowly.
  void _haze(Canvas canvas, Size size, SkyPalette pal, double t) {
    final w = size.width, h = size.height;
    final box = Rect.fromLTWH(-.35 * w, -.35 * h, 1.7 * w, 1.7 * h);
    final e = _alternate(t, 26);
    final shift = Offset(_lerp(-.04, .04, e) * box.width, _lerp(-.02, .03, e) * box.height);
    canvas.save();
    canvas.translate(box.center.dx + shift.dx, box.center.dy + shift.dy);
    canvas.rotate(_lerp(0, 7, e) * math.pi / 180);
    canvas.translate(-box.center.dx, -box.center.dy);
    _cloud(canvas, box, .24, .32, .38, .34, _k(pal.hazeA));
    _cloud(canvas, box, .78, .66, .44, .40, _k(pal.hazeB));
    canvas.restore();
  }

  void _cloud(Canvas canvas, Rect box, double cx, double cy, double rx, double ry, Color color) {
    final c = Offset(box.left + cx * box.width, box.top + cy * box.height);
    final radiusX = rx * box.width, radiusY = ry * box.height;
    final m = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(1, radiusY / radiusX, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
    canvas.drawOval(
      Rect.fromCenter(center: c, width: radiusX * 1.4, height: radiusY * 1.4),
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          radiusX,
          [color, color.withValues(alpha: 0)],
          const [0, .7],
          TileMode.clamp,
          m.storage,
        ),
    );
  }

  /// White clouds that sail slowly across the day sky (pink at dawn and dusk, none at night).
  void _paintClouds(Canvas canvas, Size size, SkyPalette pal, double t) {
    final strength = switch (phase) {
      SkyPhase.morning || SkyPhase.noon => .28,
      SkyPhase.afternoon => .22,
      SkyPhase.dawn || SkyPhase.dusk => .12,
      SkyPhase.night => 0.0,
    };
    if (strength == 0) return;
    final w = size.width, h = size.height;
    final tint = switch (phase) {
      SkyPhase.morning || SkyPhase.noon => const Color(0xFFFFFFFF),
      SkyPhase.afternoon => Color.lerp(const Color(0xFFFFFFFF), pal.sun, .45)!,
      _ => Color.lerp(const Color(0xFFFFFFFF), pal.hazeA.withValues(alpha: 1), .6)!,
    };
    final paint = Paint();
    for (final (cy, scale, crossing, offset) in _clouds) {
      final cw = w * .55 * scale;
      final span = w + 2 * cw;
      final cx = ((offset + t / crossing) % 1.0) * span - cw;
      final centre = Offset(cx, cy * h * .7);
      for (final (dx, dy, r) in _puffs) {
        final c = centre.translate(dx * cw, dy * cw);
        final radius = r * cw;
        final col = _k(tint.withValues(alpha: strength * (.75 + .25 * scale)));
        paint.shader = ui.Gradient.radial(
          c,
          radius,
          [col, col.withValues(alpha: col.a * .55), col.withValues(alpha: 0)],
          const [0, .45, 1],
        );
        canvas.drawCircle(c, radius, paint);
      }
    }
  }

  void _paintStars(Canvas canvas, Size size, SkyPalette pal, double t) {
    if (pal.stars <= 0) return;
    final w = size.width, h = size.height;
    final paint = Paint()..isAntiAlias = true;
    final white = _k(const Color(0xFFFFFFFF));

    if (_full) {
      final boxH = h * .66;
      final boost = scene.starBoost;
      // a bright moon washes out the faintest stars
      final moonWash = scene.moon.up ? 1 - .35 * scene.moon.illumination : 1.0;
      final count = _baseStars + ((_fieldStars.length - _baseStars) * boost).round();
      final spark = Paint()
        ..strokeWidth = .6
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < count; i++) {
        final st = _fieldStars[i];
        // fade out over the lower part of the star field
        final fade = st.y <= .55 ? 1.0 : 1 - (st.y - .55) / .45;
        // a sharper twinkle: mostly bright, with quick dips, and every star on its own beat
        final wave = _wave(t, st.period, st.phase);
        final tw = 1 - st.depth * wave * wave;
        final extra = i >= _baseStars ? boost : 1.0;
        final wash = st.bright > .7 ? 1.0 : moonWash;
        final a = (pal.stars * st.bright * tw * fade * extra * wash * (1 + .2 * boost)).clamp(0.0, 1.0);
        if (a <= .02) continue;
        final p = Offset(st.x * w, st.y * boxH);
        final tint = _k(st.tint);
        if (st.r > .7) {
          // the brighter ones have a soft halo, and flash a tiny cross at the top of their twinkle
          paint.color = tint.withValues(alpha: a * .12);
          canvas.drawCircle(p, st.r * 3.4, paint);
          final flash = math.pow(1 - wave, 6).toDouble();
          if (flash > .05) {
            final len = st.r * (2.5 + 4 * flash);
            spark.color = tint.withValues(alpha: a * .55 * flash);
            canvas.drawLine(p.translate(-len, 0), p.translate(len, 0), spark);
            canvas.drawLine(p.translate(0, -len), p.translate(0, len), spark);
          }
        }
        paint.color = tint.withValues(alpha: a);
        canvas.drawCircle(p, st.r, paint);
      }
      return;
    }

    final boxH = h * .70;
    var i = 0;
    for (final (sx, sy, r) in _stars) {
      final x = sx / 100 * w, y = sy / 100 * boxH;
      final fade = y <= .55 * boxH ? 1.0 : 1 - (y - .55 * boxH) / (.45 * boxH);
      // each star twinkles on its own beat
      final twinkle = 1 - .6 * _wave(t, 2.2 + (i * 7 % 5) * .45, i * 1.7);
      paint.color = white.withValues(alpha: (pal.stars * twinkle * fade).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), math.max(.6, r / 2), paint);
      i++;
    }
  }

  /// Now and then a star falls across the night sky.
  void _shootingStar(Canvas canvas, Size size, SkyPalette pal, double t) {
    if (pal.stars < .5) return;
    // more of them deep in the night
    final every = scene.starBoost > .5 ? 7.0 : 11.0;
    const lasts = .9;
    final n = (t / every).floor();
    final local = t - n * every;
    if (local > lasts) return;
    final rnd = math.Random(n * 7919 + 13);
    if (rnd.nextDouble() < .5) return; // not every time
    final w = size.width, h = size.height;
    final start = Offset((.25 + rnd.nextDouble() * .7) * w, (.04 + rnd.nextDouble() * .28) * h);
    final angle = (150 + rnd.nextDouble() * 25) * math.pi / 180; // down and to the left
    final dir = Offset(math.cos(angle), math.sin(angle));
    final travel = w * (.35 + rnd.nextDouble() * .2);
    final p = Curves.easeOutCubic.transform(local / lasts);
    final head = start + dir * (travel * p);
    final tail = head - dir * (40 + 45 * math.sin(math.pi * p));
    final alpha = math.sin(math.pi * (local / lasts)) * pal.stars * .55;
    final white = _k(const Color(0xFFFFFFFF));
    canvas.drawLine(
      tail,
      head,
      Paint()
        ..strokeWidth = .9
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(tail, head, [white.withValues(alpha: 0), white.withValues(alpha: alpha)]),
    );
  }

  /// The sun with its soft glow (and its rays on the full screen).
  void _paintSun(Canvas canvas, Size size, SkyPalette pal, double t) {
    if (!orb.sun) return;
    final w = size.width, h = size.height;
    final y = _full ? orb.yFull : orb.y;
    final c = Offset(orb.x * w, (y - .2 * (lift?.value ?? 0)) * h);
    final r = (_full ? 300.0 : 220.0) / 2;
    final s = _k(pal.sun);
    Color a(double o) => s.withValues(alpha: o);
    if (_full) _sunRays(canvas, size, c, s, t);
    final breathe = _full ? 1 + .05 * _wave(t, 6) : 1.0;
    canvas.drawCircle(
      c,
      r * breathe,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = ui.Gradient.radial(
          c,
          r * breathe,
          [a(.95), a(.95), a(.5), a(.26), a(.13), a(.05), a(.015), a(0)],
          const [0, .085, .10, .16, .28, .50, .72, .92],
        ),
    );
  }

  /// The Moon where it really is, in its real phase: lit on the right while it grows, on the left while it wanes,
  /// with the faint earthshine on its dark part at night. By day it is a pale ghost.
  void _paintMoon(Canvas canvas, Size size, double t) {
    final moon = scene.moon;
    if (!moon.up) return;
    final k = moon.illumination;
    if (k < .015) return; // new moon: nothing to see
    final w = size.width, h = size.height;
    final night = !orb.sun;
    final y = _full ? moon.yFull : moon.y;
    final c = Offset(moon.x * w, (y - .2 * (lift?.value ?? 0)) * h);
    final r = _full ? 17.0 : 13.0;
    final light = _k(const Color(0xFFF6F1DE));
    final alpha = night ? 1.0 : .62;

    if (night) {
      // the glow grows with the lit part
      final glowR = (_full ? 150.0 : 110.0) * (.55 + .45 * k) * (_full ? 1 + .06 * _wave(t, 7) : 1.0);
      canvas.drawCircle(
        c,
        glowR,
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            glowR,
            [
              light.withValues(alpha: .05 + .13 * k),
              light.withValues(alpha: .03 + .06 * k),
              light.withValues(alpha: .01 + .02 * k),
              light.withValues(alpha: 0),
            ],
            const [0, .18, .42, .75],
          ),
      );
      // earthshine: the unlit part is just visible
      canvas.drawCircle(c, r, Paint()..color = _k(const Color(0xFF9AA6C8)).withValues(alpha: .10 * (1 - k)));
    }

    // the lit part: the bright edge is a half circle, the shadow's edge a half ellipse
    final side = moon.waxing ? 1.0 : -1.0;
    final bulge = 1 - 2 * k;
    const steps = 28;
    final lit = Path();
    for (var i = 0; i <= steps; i++) {
      final a = -math.pi / 2 + math.pi * i / steps;
      final p = c.translate(side * r * math.cos(a), r * math.sin(a));
      i == 0 ? lit.moveTo(p.dx, p.dy) : lit.lineTo(p.dx, p.dy);
    }
    for (var i = steps; i >= 0; i--) {
      final a = -math.pi / 2 + math.pi * i / steps;
      lit.lineTo(c.dx + side * r * math.cos(a) * bulge, c.dy + r * math.sin(a));
    }
    lit.close();

    canvas.save();
    // the lit side leans towards the sun, which is below the horizon
    canvas.translate(c.dx, c.dy);
    canvas.rotate(side * -12 * math.pi / 180);
    canvas.translate(-c.dx, -c.dy);
    canvas.drawPath(
      lit,
      Paint()
        ..color = light.withValues(alpha: alpha)
        ..isAntiAlias = true,
    );
    // the dark seas of the Moon, only on the lit part
    canvas.clipPath(lit);
    final sea = Paint()..color = _k(const Color(0xFF8E8A7C)).withValues(alpha: .13 * alpha);
    canvas.drawCircle(c.translate(-r * .28, -r * .3), r * .3, sea);
    canvas.drawCircle(c.translate(r * .25, -r * .1), r * .22, sea);
    canvas.drawCircle(c.translate(-r * .05, r * .35), r * .2, sea);
    canvas.drawCircle(c.translate(r * .42, r * .38), r * .12, sea);
    canvas.restore();
  }

  /// The colour of the hour, laid softly over the sky.
  void _hourTint(Canvas canvas, Size size) {
    final s = scene.tintStrength * (_full ? 1 : .7);
    if (s <= 0) return;
    final c = _k(Color(scene.tint));
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          [c.withValues(alpha: s * .55), c.withValues(alpha: s), c.withValues(alpha: s * .7)],
          const [0, .6, 1],
        ),
    );
  }

  /// The Milky Way: a faint, dusty band across the sky in the darkest hours.
  void _milkyWay(Canvas canvas, Size size, SkyPalette pal) {
    final m = scene.milkyWay * pal.stars * (scene.moon.up ? 1 - .6 * scene.moon.illumination : 1);
    if (m <= .02) return;
    final w = size.width, h = size.height;
    final from = Offset(-.1 * w, .52 * h), to = Offset(1.1 * w, .02 * h);
    final dir = to - from;
    final len = dir.distance;
    final u = dir / len;
    final n = Offset(-u.dy, u.dx);
    final half = math.min(w, h) * .16;
    canvas.save();
    canvas.translate(from.dx, from.dy);
    canvas.rotate(math.atan2(u.dy, u.dx));
    final band = Rect.fromLTWH(0, -half, len, 2 * half);
    canvas.drawRect(
      band,
      Paint()
        ..shader = ui.Gradient.linear(
          band.topLeft,
          band.bottomLeft,
          [
            const Color(0x00C8D2FF),
            _k(Color.fromRGBO(200, 210, 255, .07 * m)),
            _k(Color.fromRGBO(235, 228, 255, .10 * m)),
            _k(Color.fromRGBO(200, 210, 255, .07 * m)),
            const Color(0x00C8D2FF),
          ],
          const [0, .3, .5, .7, 1],
        ),
    );
    canvas.restore();
    final dust = Paint();
    final white = _k(const Color(0xFFEAEFFF));
    for (final (along, across, r, b) in _milkyDust) {
      final p = from + u * (along * len) + n * (across * half * .9);
      if (p.dy > h * .62) continue;
      dust.color = white.withValues(alpha: b * .5 * m);
      canvas.drawCircle(p, r, dust);
    }
  }

  /// The morning star before sunrise (in the east) and the evening star after sunset (in the west).
  void _brightStar(Canvas canvas, Size size, double t) {
    final s = scene.brightStar;
    if (s <= .02) return;
    final w = size.width, h = size.height;
    final morning = scene.hour < 12;
    final p = Offset((morning ? .1 : .9) * w, h * .7);
    final white = _k(const Color(0xFFFFF8EC));
    final pulse = .85 + .15 * _wave(t, 2.6);
    canvas.drawCircle(p, 9, Paint()..color = white.withValues(alpha: .10 * s * pulse));
    final ray = Paint()
      ..strokeWidth = .8
      ..strokeCap = StrokeCap.round
      ..color = white.withValues(alpha: .5 * s * pulse);
    final len = 6 + 3 * pulse;
    canvas.drawLine(p.translate(-len, 0), p.translate(len, 0), ray);
    canvas.drawLine(p.translate(0, -len), p.translate(0, len), ray);
    canvas.drawCircle(p, 1.8, Paint()..color = white.withValues(alpha: s));
  }

  /// A small flock in a loose V, out in the morning and home in the evening.
  void _birds(Canvas canvas, Size size, double t) {
    final s = scene.birds;
    if (s <= .02) return;
    const every = 46.0, crossing = 30.0;
    final n = (t / every).floor();
    final local = t - n * every;
    if (local > crossing) return;
    final rnd = math.Random(n * 4513 + 7);
    final w = size.width, h = size.height;
    final morning = scene.hour < 12;
    final p = local / crossing;
    final x = morning ? -.15 + 1.3 * p : 1.15 - 1.3 * p;
    final y = (.2 + rnd.nextDouble() * .25) * h + math.sin(p * math.pi * 2) * 6;
    final color = _k(orb.sun ? const Color(0xFF1E2438) : const Color(0xFF0E0F1E)).withValues(alpha: .55 * s);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final count = 4 + rnd.nextInt(4);
    final back = morning ? -1.0 : 1.0;
    for (var i = 0; i < count; i++) {
      final row = (i + 1) ~/ 2, side = i.isOdd ? -1.0 : 1.0;
      final c = Offset(x * w + back * row * 14, y + side * row * 9 + rnd.nextDouble() * 3);
      final flap = math.sin(t * 9 + i * 1.3);
      final span = 5.0 + rnd.nextDouble() * 1.5;
      final lift = 2.5 * flap;
      final path = Path()
        ..moveTo(c.dx - span, c.dy - lift)
        ..quadraticBezierTo(c.dx - span * .4, c.dy - lift * .3 - 1.2, c.dx, c.dy)
        ..quadraticBezierTo(c.dx + span * .4, c.dy - lift * .3 - 1.2, c.dx + span, c.dy - lift);
      canvas.drawPath(path, paint);
    }
  }

  /// A plane high up in the day sky, leaving a thin trail that slowly fades.
  void _plane(Canvas canvas, Size size, double t) {
    final s = scene.plane;
    if (s <= .02) return;
    const every = 80.0, crossing = 55.0;
    final n = (t / every).floor();
    final local = t - n * every;
    if (local > crossing + 12) return;
    final rnd = math.Random(n * 2861 + 3);
    if (rnd.nextDouble() < .35) return; // not every time
    final w = size.width, h = size.height;
    final ltr = rnd.nextBool();
    final y0 = (.08 + rnd.nextDouble() * .22) * h, y1 = y0 + (rnd.nextDouble() - .5) * .12 * h;
    Offset at(double p) => Offset((ltr ? -.05 + 1.1 * p : 1.05 - 1.1 * p) * w, y0 + (y1 - y0) * p);
    final p = (local / crossing).clamp(0.0, 1.0);
    final head = at(p);
    final tail = at(math.max(0, p - .35));
    final fade = local > crossing ? 1 - (local - crossing) / 12 : 1.0;
    final white = _k(const Color(0xFFFFFFFF));
    canvas.drawLine(
      tail,
      head,
      Paint()
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(tail, head, [
          white.withValues(alpha: 0),
          white.withValues(alpha: .35 * s * fade),
        ]),
    );
    if (local <= crossing) canvas.drawCircle(head, 1.3, Paint()..color = white.withValues(alpha: .8 * s));
  }

  /// A plane's lights blinking across the evening sky.
  void _nightPlane(Canvas canvas, Size size, double t) {
    final s = scene.nightPlane;
    if (s <= .02) return;
    const every = 95.0, crossing = 70.0;
    final n = (t / every).floor();
    final local = t - n * every;
    if (local > crossing) return;
    final rnd = math.Random(n * 1733 + 11);
    if (rnd.nextDouble() < .4) return;
    final w = size.width, h = size.height;
    final ltr = rnd.nextBool();
    final p = local / crossing;
    final y = (.1 + rnd.nextDouble() * .25) * h + p * 20;
    final c = Offset((ltr ? -.05 + 1.1 * p : 1.05 - 1.1 * p) * w, y);
    canvas.drawCircle(c, .9, Paint()..color = _k(const Color(0xFFFFFFFF)).withValues(alpha: .55 * s));
    final blink = (t * 1.1) % 1.0;
    if (blink < .12) {
      canvas.drawCircle(c, 3.2, Paint()..color = _k(const Color(0xFFFF5A5A)).withValues(alpha: .25 * s));
      canvas.drawCircle(c, 1.3, Paint()..color = _k(const Color(0xFFFF6B6B)).withValues(alpha: .95 * s));
    } else if (blink > .5 && blink < .58) {
      canvas.drawCircle(c, 3.0, Paint()..color = _k(const Color(0xFFFFFFFF)).withValues(alpha: .25 * s));
      canvas.drawCircle(c, 1.2, Paint()..color = _k(const Color(0xFFFFFFFF)).withValues(alpha: .95 * s));
    }
  }

  /// Fireflies drifting over the meadows on summer evenings.
  void _paintFireflies(Canvas canvas, Size size, double t) {
    final s = scene.fireflies;
    if (s <= .02) return;
    final w = size.width, h = size.height;
    final glow = _k(const Color(0xFFE8FF8A));
    final paint = Paint();
    for (final (x, y, speed, phase) in _fireflies) {
      final c = Offset(
        (x + .04 * math.sin(t * .3 * speed + phase)) * w,
        y * h + 12 * math.sin(t * .45 * speed + phase * 2),
      );
      final on = math.pow(math.max(0.0, math.sin(t * 1.3 * speed + phase)), 3).toDouble() * s;
      if (on < .03) continue;
      paint.color = glow.withValues(alpha: .18 * on);
      canvas.drawCircle(c, 5, paint);
      paint.color = glow.withValues(alpha: .9 * on);
      canvas.drawCircle(c, 1.4, paint);
    }
  }

  /// A few faint, soft beams that turn very slowly around the sun and breathe in and out.
  void _sunRays(Canvas canvas, Size size, Offset c, Color sun, double t) {
    final reach = size.shortestSide * .95;
    void beams(int count, double turn, double width, double alpha) {
      final path = Path();
      for (var i = 0; i < count; i++) {
        final a = turn + i * 2 * math.pi / count;
        final half = width * (i.isEven ? 1 : .55);
        path
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + reach * math.cos(a - half), c.dy + reach * math.sin(a - half))
          ..lineTo(c.dx + reach * math.cos(a + half), c.dy + reach * math.sin(a + half))
          ..close();
      }
      canvas.drawPath(
        path,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = ui.Gradient.radial(
            c,
            reach,
            [sun.withValues(alpha: alpha), sun.withValues(alpha: alpha * .3), sun.withValues(alpha: 0)],
            const [0, .25, .8],
          ),
      );
    }

    final strength = phase == SkyPhase.noon ? .06 : .08;
    beams(8, t * .02, .07, strength * (.7 + .3 * _wave(t, 10)));
    beams(6, -t * .013 + .5, .05, strength * .6 * (.7 + .3 * _wave(t, 13, 1.3)));
  }

  void _hills(Canvas canvas, Size size, SkyPalette pal) {
    final w = size.width, h = size.height;
    final hh = _full ? math.min(.20 * h, 170.0) : math.min(.26 * h, 64.0);
    final sx = w / 400, sy = hh / 60, top = h - hh;
    canvas.save();
    canvas.translate(0, top);
    canvas.scale(sx, sy);
    final hill = _k(pal.hill);
    canvas.drawPath(
      _farHillPath,
      Paint()
        ..color = hill.withValues(alpha: hill.a * .55)
        ..isAntiAlias = true,
    );
    canvas.restore();
    // morning mist lying in the valley, between the far hills and the near ones
    if (_full && scene.mist > .02) {
      final mist = _k(const Color(0xFFF4F1F8));
      for (final (cx, cy, rx, a) in const [(.2, 30.0, .32, 1.0), (.62, 26.0, .4, .8), (.95, 32.0, .28, .9)]) {
        final c = Offset(cx * w, top + cy * sy);
        final rect = Rect.fromCenter(center: c, width: rx * 2 * w, height: 22 * sy);
        canvas.drawOval(
          rect,
          Paint()
            ..shader = ui.Gradient.radial(
              c,
              rx * w,
              [mist.withValues(alpha: .34 * a * scene.mist), mist.withValues(alpha: 0)],
              const [0, 1],
              TileMode.clamp,
              (Matrix4.identity()
                    ..translateByDouble(c.dx, c.dy, 0, 1)
                    ..scaleByDouble(1, rect.height / rect.width, 1, 1)
                    ..translateByDouble(-c.dx, -c.dy, 0, 1))
                  .storage,
            ),
        );
      }
    }
    canvas.save();
    canvas.translate(0, top);
    canvas.scale(sx, sy);
    canvas.drawPath(
      _nearHillPath,
      Paint()
        ..color = hill
        ..isAntiAlias = true,
    );
    canvas.restore();
    // the lit windows of the villages
    final lights = _full ? scene.townLights : 0.0;
    if (lights > .02) {
      final glow = Paint();
      final dot = Paint();
      for (final (x, y, warmth, order) in _windows) {
        if (order > lights) continue; // the windows go out one by one
        final c = Offset(x * sx, top + y * sy);
        final color = _k(Color.lerp(const Color(0xFFFFD27A), const Color(0xFFFFF2D2), warmth)!);
        glow.color = color.withValues(alpha: .16);
        canvas.drawCircle(c, 3.2, glow);
        dot.color = color.withValues(alpha: .9);
        canvas.drawCircle(c, .95, dot);
      }
    }
  }

  /// A gentle shade behind the numbers (so they stay crisp on the brightest skies); red while a prayer is forbidden.
  void _veil(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    void ellipse(double cx, double cy, double rx, double ry, double alpha) {
      final c = Offset(cx * w, cy * h);
      final radiusX = rx * w, radiusY = ry * h;
      final m = Matrix4.identity()
        ..translateByDouble(c.dx, c.dy, 0, 1)
        ..scaleByDouble(1, radiusY / radiusX, 1, 1)
        ..translateByDouble(-c.dx, -c.dy, 0, 1);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            radiusX,
            [Color.fromRGBO(0, 0, 0, alpha), const Color(0x00000000)],
            const [0, .78],
            TileMode.clamp,
            m.storage,
          ),
      );
    }

    if (_full) {
      ellipse(.5, .5, .70, .34, forbidden ? .16 : .20);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(0, h),
            const [Color(0x4D000000), Color(0x00000000), Color(0x00000000), Color(0x57000000)],
            const [0, .24, .70, 1],
          ),
      );
    } else {
      ellipse(.5, .52, .75, .55, forbidden ? .14 : .16);
    }
    if (forbidden) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [
            _k(const Color.fromRGBO(120, 18, 22, .72)),
            _k(const Color.fromRGBO(70, 8, 16, .82)),
          ]),
      );
    }
  }

  @override
  bool shouldRepaint(SkyPainter old) =>
      old.layer != layer ||
      old.phase != phase ||
      old.forbidden != forbidden ||
      old.mode != mode ||
      old.dark != dark ||
      old.radius != radius ||
      old.clock != clock ||
      old.lift != lift ||
      old.scene != scene ||
      (layer == SkyLayer.motion &&
          (old.orb.sun != orb.sun || old.orb.x != orb.x || old.orb.y != orb.y || old.orb.yFull != orb.yFull));
}

/// The card with the sky behind its content.
class SkyCard extends StatelessWidget {
  const SkyCard({
    super.key,
    required this.model,
    required this.mode,
    required this.clock,
    required this.child,
    this.lift,
  });

  final TodayModel model;
  final SkyMode mode;
  final SkyClock? clock;
  final Widget child;
  final Animation<double>? lift;

  @override
  Widget build(BuildContext context) {
    final dark = context.colors.dark;
    final pal = skyPalettes[model.phase]!;
    final forbidden = model.card?.forbidden ?? false;
    final full = mode == SkyMode.full;
    final radius = full ? 0.0 : 28.0;

    Widget layer(SkyLayer l) => Positioned.fill(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: SkyPainter(
            layer: l,
            phase: model.phase,
            orb: model.orb,
            scene: model.scene,
            forbidden: forbidden,
            mode: mode,
            dark: dark,
            radius: radius,
            clock: clock,
            lift: lift,
          ),
        ),
      ),
    );

    Widget card = Stack(
      fit: full ? StackFit.expand : StackFit.loose,
      children: [layer(SkyLayer.back), layer(SkyLayer.motion), layer(SkyLayer.front), child],
    );
    if (!full) card = ClipRRect(borderRadius: BorderRadius.circular(radius), child: card);
    if (full) return card;

    Widget halo = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: forbidden ? const Color(0xFF8C2A2A) : null,
        gradient: forbidden
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: pal.colors,
                stops: pal.stops,
              ),
      ),
    );
    if (dark) halo = ColorFiltered(colorFilter: _darkFilter, child: halo);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // blurred halo of the same sky, so the card glows into the page
        Positioned(
          left: 18,
          right: 18,
          top: 22,
          bottom: -12,
          child: ExcludeSemantics(
            child: RepaintBoundary(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Opacity(opacity: dark ? .4 : .5, child: halo),
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              const BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
              BoxShadow(
                color: pal.glow.withValues(alpha: .75),
                blurRadius: 44,
                spreadRadius: -20,
                offset: const Offset(0, 22),
              ),
            ],
          ),
          child: card,
        ),
      ],
    );
  }
}

/// A soft wash of the current sky behind the whole page:
/// CSS `radial-gradient(70% 60% at 50% 22%, glow, transparent 72%)` over the top 75% of the screen.
class PageGlow extends StatelessWidget {
  const PageGlow({super.key, required this.phase});

  final SkyPhase phase;

  @override
  Widget build(BuildContext context) {
    final dark = context.colors.dark;
    final glow = skyPalettes[phase]!.glow;
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: MediaQuery.sizeOf(context).height * .75,
      child: IgnorePointer(
        child: Opacity(
          opacity: dark ? .26 : .2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -.56),
                radius: 1,
                colors: [glow, glow.withValues(alpha: 0)],
                stops: const [0, .72],
                transform: const _EllipseTransform(.7, .6, .22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Turns a unit radial gradient into an ellipse with radii [rx]·width and [ry]·height,
/// centred [cy]·height from the top.
class _EllipseTransform extends GradientTransform {
  const _EllipseTransform(this.rx, this.ry, this.cy);

  final double rx;
  final double ry;
  final double cy;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final shortest = bounds.shortestSide;
    final cx = bounds.center.dx;
    final y = bounds.top + bounds.height * cy;
    return Matrix4.identity()
      ..translateByDouble(cx, y, 0, 1)
      ..scaleByDouble(rx * bounds.width / shortest, ry * bounds.height / shortest, 1, 1)
      ..translateByDouble(-cx, -y, 0, 1);
  }
}
