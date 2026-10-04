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

  /// A taller, centred card (the prayer list is hidden).
  focus,

  /// The sky fills the whole screen (prayer list and tips both hidden).
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

  double get seconds => (_base + _elapsed).inMicroseconds / 1e6;

  void _onTick(Duration elapsed) {
    _elapsed = elapsed;
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

/// A star of the full-screen sky: where it is (0–1), how big, and how it twinkles.
class _Star {
  const _Star(this.x, this.y, this.r, this.period, this.phase, this.depth);

  final double x;
  final double y;
  final double r;
  final double period;
  final double phase;

  /// How far the star dims at the bottom of its twinkle (0 = steady, 1 = goes out).
  final double depth;
}

/// The same stars on every start (a fixed seed), scattered over the upper sky, a few of them bright.
final List<_Star> _fieldStars = () {
  final rnd = math.Random(1447);
  return List<_Star>.generate(140, (i) {
    final bright = i % 11 == 0;
    final y = math.pow(rnd.nextDouble(), 1.35).toDouble(); // denser towards the top
    return _Star(
      rnd.nextDouble(),
      y,
      bright ? 2.2 + rnd.nextDouble() * .8 : 1.1 + rnd.nextDouble() * 1.1,
      2.2 + rnd.nextDouble() * 4.5,
      rnd.nextDouble() * 2 * math.pi,
      bright ? .35 : .45 + rnd.nextDouble() * .5,
    );
  });
}();

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
      case SkyLayer.motion:
        final t = clock?.seconds ?? 0.0;
        final live = clock != null;
        _haze(canvas, size, pal, t);
        if (_full) _paintClouds(canvas, size, pal, t);
        _paintStars(canvas, size, pal, t);
        if (_full && live) _shootingStar(canvas, size, pal, t);
        _paintOrb(canvas, size, pal, t);
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
      final glint = Paint()
        ..isAntiAlias = true
        ..strokeCap = StrokeCap.round;
      for (final s in _fieldStars) {
        final y = s.y * boxH;
        // fade out over the lower part of the star field
        final fade = s.y <= .55 ? 1.0 : 1 - (s.y - .55) / .45;
        final tw = 1 - s.depth * _wave(t, s.period, s.phase);
        final a = (pal.stars * tw * fade).clamp(0.0, 1.0);
        if (a <= .02) continue;
        final p = Offset(s.x * w, y);
        paint.color = white.withValues(alpha: a);
        canvas.drawCircle(p, s.r / 2, paint);
        if (s.r > 2.1) {
          // the bright ones sparkle: a soft halo and a little cross of light
          paint.color = white.withValues(alpha: a * .16);
          canvas.drawCircle(p, s.r * 1.8, paint);
          final len = s.r * (2.2 + 2.2 * tw);
          glint
            ..color = white.withValues(alpha: a * .55)
            ..strokeWidth = .7;
          canvas.drawLine(p.translate(-len, 0), p.translate(len, 0), glint);
          canvas.drawLine(p.translate(0, -len), p.translate(0, len), glint);
        }
      }
      return;
    }

    final boxH = h * .70;
    var i = 0;
    for (final (sx, sy, r) in _stars) {
      final x = sx / 100 * w, y = sy / 100 * boxH;
      final fade = y <= .55 * boxH ? 1.0 : 1 - (y - .55 * boxH) / (.45 * boxH);
      // each star twinkles on its own beat
      final twinkle = 1 - .5 * _wave(t, 3.2 + (i * 7 % 5) * .55, i * 1.7);
      paint.color = white.withValues(alpha: (pal.stars * twinkle * fade).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), math.max(.6, r / 2), paint);
      i++;
    }
  }

  /// Now and then a star falls across the night sky.
  void _shootingStar(Canvas canvas, Size size, SkyPalette pal, double t) {
    if (pal.stars < .5) return;
    const every = 7.0, lasts = 1.1;
    final n = (t / every).floor();
    final local = t - n * every;
    if (local > lasts) return;
    final rnd = math.Random(n * 7919 + 13);
    if (rnd.nextDouble() < .35) return; // not every time
    final w = size.width, h = size.height;
    final start = Offset((.25 + rnd.nextDouble() * .7) * w, (.04 + rnd.nextDouble() * .28) * h);
    final angle = (150 + rnd.nextDouble() * 25) * math.pi / 180; // down and to the left
    final dir = Offset(math.cos(angle), math.sin(angle));
    final travel = w * (.35 + rnd.nextDouble() * .2);
    final p = Curves.easeOutCubic.transform(local / lasts);
    final head = start + dir * (travel * p);
    final tail = head - dir * (70 + 60 * math.sin(math.pi * p));
    final alpha = math.sin(math.pi * (local / lasts)) * pal.stars;
    final white = _k(const Color(0xFFFFFFFF));
    canvas.drawLine(
      tail,
      head,
      Paint()
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(tail, head, [white.withValues(alpha: 0), white.withValues(alpha: alpha * .9)]),
    );
    canvas.drawCircle(head, 1.6, Paint()..color = white.withValues(alpha: alpha));
  }

  /// The sun with its rays, or the moon with a crescent.
  void _paintOrb(Canvas canvas, Size size, SkyPalette pal, double t) {
    final w = size.width, h = size.height;
    final y = switch (mode) {
      SkyMode.full => orb.yFull,
      SkyMode.focus => orb.yFocus,
      SkyMode.card => orb.y,
    };
    final c = Offset(orb.x * w, (y - .2 * (lift?.value ?? 0)) * h);
    final r = (_full ? 300.0 : 220.0) / 2;
    if (orb.sun) {
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
      return;
    }
    final moon = _k(const Color(0xFFF3EEDA));
    final glowR = r * (_full ? 1 + .08 * _wave(t, 7) : 1.0);
    canvas.drawCircle(
      c,
      glowR,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          glowR,
          [
            moon.withValues(alpha: .16),
            moon.withValues(alpha: .08),
            moon.withValues(alpha: .03),
            moon.withValues(alpha: 0),
          ],
          const [0, .18, .42, .75],
        ),
    );
    final disc = Path()..addOval(Rect.fromCircle(center: c, radius: 14));
    final hole = Path()..addOval(Rect.fromCircle(center: c.translate(8, -3), radius: 14));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-18 * math.pi / 180);
    canvas.translate(-c.dx, -c.dy);
    canvas.drawPath(
      Path.combine(PathOperation.difference, disc, hole),
      Paint()
        ..color = moon
        ..isAntiAlias = true,
    );
    canvas.restore();
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
    canvas.save();
    canvas.translate(0, h - hh);
    canvas.scale(w / 400, hh / 60);
    final far = Path()
      ..moveTo(0, 34)
      ..cubicTo(30, 27, 58, 30, 92, 22)
      ..relativeCubicTo(30, -7, 52, 2, 84, 6)
      ..relativeCubicTo(34, 4, 58, -17, 96, -19)
      ..relativeCubicTo(30, -2, 48, 12, 76, 13)
      ..relativeCubicTo(22, 1, 36, -6, 52, -8)
      ..lineTo(400, 60)
      ..lineTo(0, 60)
      ..close();
    final near = Path()
      ..moveTo(0, 46)
      ..relativeCubicTo(36, -7, 66, -2, 104, -9)
      ..relativeCubicTo(40, -7, 70, 6, 112, 5)
      ..relativeCubicTo(40, -1, 64, -12, 102, -12)
      ..relativeCubicTo(34, 0, 58, 8, 82, 6)
      ..lineTo(400, 60)
      ..lineTo(0, 60)
      ..close();
    final hill = _k(pal.hill);
    canvas.drawPath(
      far,
      Paint()
        ..color = hill.withValues(alpha: hill.a * .55)
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      near,
      Paint()
        ..color = hill
        ..isAntiAlias = true,
    );
    canvas.restore();
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
      (layer == SkyLayer.motion &&
          (old.orb.sun != orb.sun ||
              old.orb.x != orb.x ||
              old.orb.y != orb.y ||
              old.orb.yFocus != orb.yFocus ||
              old.orb.yFull != orb.yFull));
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
