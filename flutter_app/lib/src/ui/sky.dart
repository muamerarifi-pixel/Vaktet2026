import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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

/// Drives the slow drift of the haze and the twinkling of the stars (a few frames a second is plenty).
class SkyClock extends ChangeNotifier {
  final Stopwatch _watch = Stopwatch()..start();
  Timer? _timer;

  double get seconds => _watch.elapsedMicroseconds / 1e6;

  void start() => _timer ??= Timer.periodic(const Duration(milliseconds: 200), (_) => notifyListeners());

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

// brightness(.86) saturate(.95): the same skies, a little dimmer at night so they don't glare.
final ColorFilter _darkFilter = () {
  const s = 0.95, b = 0.86;
  final m = <double>[
    0.213 + 0.787 * s,
    0.715 - 0.715 * s,
    0.072 - 0.072 * s,
    0.213 - 0.213 * s,
    0.715 + 0.285 * s,
    0.072 - 0.072 * s,
    0.213 - 0.213 * s,
    0.715 - 0.715 * s,
    0.072 + 0.928 * s,
  ];
  return ColorFilter.matrix([
    m[0] * b, m[1] * b, m[2] * b, 0, 0, //
    m[3] * b, m[4] * b, m[5] * b, 0, 0,
    m[6] * b, m[7] * b, m[8] * b, 0, 0,
    0, 0, 0, 1, 0,
  ]);
}();

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

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// A value that goes 0 → 1 → 0 with ease-in-out, like a CSS `alternate` animation.
double _alternate(double seconds, double duration) {
  final cycle = (seconds / duration) % 2.0;
  return Curves.easeInOut.transform(cycle <= 1 ? cycle : 2 - cycle);
}

class SkyPainter extends CustomPainter {
  SkyPainter({
    required this.phase,
    required this.orb,
    required this.forbidden,
    required this.mode,
    required this.dark,
    required this.radius,
    this.clock,
  }) : super(repaint: clock);

  final SkyPhase phase;
  final OrbState orb;
  final bool forbidden;
  final SkyMode mode;
  final bool dark;
  final double radius;

  /// Null when animations are off.
  final SkyClock? clock;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    final rect = Offset.zero & size;
    final pal = skyPalettes[phase]!;
    final t = clock?.seconds ?? 0.0;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    canvas.save();
    if (radius > 0) canvas.clipRRect(rr);
    if (dark) canvas.saveLayer(rect, Paint()..colorFilter = _darkFilter);

    canvas.drawRect(rect, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), pal.colors, pal.stops));
    _haze(canvas, size, pal, t);
    _paintStars(canvas, size, pal, t);
    _paintOrb(canvas, size, pal);
    _hills(canvas, size, pal);
    _veil(canvas, size);
    // glass sheen along the top edge
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h * .38), [
          const Color(0x29FFFFFF),
          const Color(0x00FFFFFF),
        ]),
    );

    if (dark) canvas.restore();
    if (radius > 0) {
      // a 1px highlight inside the top edge
      final edge = Path.combine(
        PathOperation.difference,
        Path()..addRRect(rr),
        Path()..addRRect(rr.shift(const Offset(0, 1))),
      );
      canvas.drawPath(edge, Paint()..color = const Color(0x38FFFFFF));
    }
    canvas.restore();
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
    _cloud(canvas, box, .24, .32, .38, .34, pal.hazeA);
    _cloud(canvas, box, .78, .66, .44, .40, pal.hazeB);
    canvas.restore();
  }

  void _cloud(Canvas canvas, Rect box, double cx, double cy, double rx, double ry, Color color) {
    final c = Offset(box.left + cx * box.width, box.top + cy * box.height);
    final radiusX = rx * box.width, radiusY = ry * box.height;
    final m = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(1, radiusY / radiusX, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
    canvas.drawRect(
      box,
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

  void _paintStars(Canvas canvas, Size size, SkyPalette pal, double t) {
    if (pal.stars <= 0) return;
    final w = size.width, h = size.height;
    final boxH = h * (mode == SkyMode.full ? .62 : .70);
    final tileW = mode == SkyMode.full ? 300.0 : w;
    final tileH = mode == SkyMode.full ? 270.0 : boxH;
    final twinkle = 1 - .45 * _alternate(t, 5);
    final paint = Paint()..isAntiAlias = true;
    for (var ty = 0.0; ty < boxH; ty += tileH) {
      for (var tx = 0.0; tx < w; tx += tileW) {
        for (final (sx, sy, r) in _stars) {
          final x = tx + sx / 100 * tileW, y = ty + sy / 100 * tileH;
          if (y >= boxH || x >= w) continue;
          // fade out over the lower part of the star field
          final fade = y <= .55 * boxH ? 1.0 : 1 - (y - .55 * boxH) / (.45 * boxH);
          paint.color = Color.fromRGBO(255, 255, 255, (pal.stars * twinkle * fade).clamp(0.0, 1.0));
          canvas.drawCircle(Offset(x, y), math.max(.6, r / 2), paint);
        }
      }
    }
  }

  /// The sun, or the moon with a crescent.
  void _paintOrb(Canvas canvas, Size size, SkyPalette pal) {
    final w = size.width, h = size.height;
    final y = switch (mode) {
      SkyMode.full => orb.yFull,
      SkyMode.focus => orb.yFocus,
      SkyMode.card => orb.y,
    };
    final c = Offset(orb.x * w, y * h);
    final r = (mode == SkyMode.full ? 300.0 : 220.0) / 2;
    if (orb.sun) {
      final s = pal.sun;
      Color a(double o) => s.withValues(alpha: o);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = ui.Gradient.radial(
            c,
            r,
            [a(.95), a(.95), a(.5), a(.26), a(.13), a(.05), a(.015), a(0)],
            const [0, .085, .10, .16, .28, .50, .72, .92],
          ),
      );
      return;
    }
    const moon = Color(0xFFF3EEDA);
    final glow = Color.fromRGBO(243, 238, 218, 1);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          r,
          [
            glow.withValues(alpha: .16),
            glow.withValues(alpha: .08),
            glow.withValues(alpha: .03),
            glow.withValues(alpha: 0),
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

  void _hills(Canvas canvas, Size size, SkyPalette pal) {
    final w = size.width, h = size.height;
    final hh = mode == SkyMode.full ? math.min(.20 * h, 170.0) : math.min(.26 * h, 64.0);
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
    canvas.drawPath(
      far,
      Paint()
        ..color = pal.hill.withValues(alpha: pal.hill.a * .55)
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      near,
      Paint()
        ..color = pal.hill
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  /// A gentle shade behind the numbers (so they stay crisp on the brightest skies); red while a prayer is forbidden.
  void _veil(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    final full = mode == SkyMode.full;
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

    if (full) {
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
          ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), const [
            Color.fromRGBO(120, 18, 22, .72),
            Color.fromRGBO(70, 8, 16, .82),
          ]),
      );
    }
  }

  @override
  bool shouldRepaint(SkyPainter old) =>
      old.phase != phase ||
      old.forbidden != forbidden ||
      old.mode != mode ||
      old.dark != dark ||
      old.radius != radius ||
      old.clock != clock ||
      old.orb.sun != orb.sun ||
      old.orb.x != orb.x ||
      old.orb.y != orb.y ||
      old.orb.yFocus != orb.yFocus ||
      old.orb.yFull != orb.yFull;
}

/// The card with the sky behind its content.
class SkyCard extends StatelessWidget {
  const SkyCard({super.key, required this.model, required this.mode, required this.clock, required this.child});

  final TodayModel model;
  final SkyMode mode;
  final SkyClock? clock;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = context.colors.dark;
    final pal = skyPalettes[model.phase]!;
    final forbidden = model.card?.forbidden ?? false;
    final full = mode == SkyMode.full;
    final radius = full ? 0.0 : 28.0;

    final card = Stack(
      fit: full ? StackFit.expand : StackFit.loose,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: SkyPainter(
                phase: model.phase,
                orb: model.orb,
                forbidden: forbidden,
                mode: mode,
                dark: dark,
                radius: radius,
                clock: clock,
              ),
            ),
          ),
        ),
        child,
      ],
    );
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
