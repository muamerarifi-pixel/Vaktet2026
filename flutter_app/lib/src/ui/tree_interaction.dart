import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/prayer.dart';
import 'sky.dart' show SkyClock;

/// Botanical leaf drawer matching the tree in landscape.dart.
void _drawLeaf(Path path, Offset center, double len, double wid, double angle) {
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
  final c3y = center.dy - uy * (len * 0.22) - ny * (wid * 0.48);
  final c4x = center.dx - ux * (len * 0.12) - nx * (wid * 0.55);
  final c4y = center.dy - uy * (len * 0.12) - ny * (wid * 0.55);

  path
    ..moveTo(bx, by)
    ..cubicTo(c1x, c1y, c2x, c2y, tx, ty)
    ..cubicTo(c3x, c3y, c4x, c4y, bx, by)
    ..close();
}

class _FallingLeaf {
  _FallingLeaf({
    required this.start,
    required this.vx,
    required this.vy,
    required this.len,
    required this.wid,
    required this.angle,
    required this.rotSpeed,
    required this.color,
    required this.spawnTime,
    required this.phase,
    required this.isSnow,
  });

  final Offset start;
  final double vx;
  final double vy;
  final double len;
  final double wid;
  final double angle;
  final double rotSpeed;
  final Color color;
  final double spawnTime;
  final double phase;
  final bool isSnow;

  double? landTime;
  Offset? landPos;
}

class _Firefly {
  _Firefly({
    required this.start,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.color,
    required this.spawnTime,
    required this.phase,
  });

  final Offset start;
  final double vx;
  final double vy;
  final double radius;
  final Color color;
  final double spawnTime;
  final double phase;
}

class _WaterRipple {
  _WaterRipple({
    required this.pos,
    required this.color,
    required this.spawnTime,
    this.maxRadius = 22.0,
  });

  static const double duration = 1.6;

  final Offset pos;
  final Color color;
  final double spawnTime;
  final double maxRadius;
}

class _StartledBird {
  _StartledBird({
    required this.start,
    required this.spawnTime,
    required this.color,
  });

  final Offset start;
  final double spawnTime;
  final Color color;
}

/// Manages interactive touch reactions on the landscape tree:
/// - Dynamic physical rustle & spring sway on branches
/// - Falling detailed leaves tumbling in the wind
/// - Rising glowing fireflies startled from the boughs at night
/// - Expanding circular water ripples when leaves touch the lake
/// - Secret bird taking flight on quick multiple taps
class TreeInteraction extends ChangeNotifier {
  TreeInteraction._();

  static final TreeInteraction shared = TreeInteraction._();

  final math.Random _rnd = math.Random();

  final List<(double, double)> _tapImpulses = [];
  final List<_FallingLeaf> _leaves = [];
  final List<_Firefly> _fireflies = [];
  final List<_WaterRipple> _ripples = [];
  _StartledBird? _activeBird;

  double _lastTapTime = -10.0;
  int _consecutiveTaps = 0;
  Timer? _releaseTimer;

  /// Returns whether a screen touch point is within the tree's hit area.
  static bool isTreeHit(Offset pos, Size size) {
    if (size.width <= 0 || size.height <= 0) return false;
    final boxH = math.min(.23 * size.height, 196.0);
    final top = size.height - boxH;
    final treeX = (70.0 / 400.0) * size.width;
    final treeY = top + 83.6 * boxH / 100.0;
    final u = boxH / 100.0;
    final s = u * 0.8;

    // Hit bounds covering tree canopy and shore base with comfortable padding
    final hitRect = Rect.fromLTRB(
      treeX - 75 * s - 25,
      treeY - 150 * s - 25,
      treeX + 75 * s + 25,
      treeY + 25 * s + 25,
    );
    return hitRect.contains(pos);
  }

  /// Triggers a touch interaction on the tree.
  void tap(Offset pos, Size size, SkyScene scene, {bool isDay = true}) {
    final t = SkyClock.shared.seconds;
    HapticFeedback.lightImpact();

    // Check consecutive taps for easter egg
    if (t - _lastTapTime < 1.6) {
      _consecutiveTaps++;
    } else {
      _consecutiveTaps = 1;
    }
    _lastTapTime = t;

    // Keep the sky clock running for smooth animation
    SkyClock.shared.hold(this);
    _releaseTimer?.cancel();
    _releaseTimer = Timer(const Duration(milliseconds: 4200), () {
      SkyClock.shared.release(this);
    });

    // Add branch sway impulse
    final intensity = (_consecutiveTaps > 2 ? 1.6 : 1.1) + _rnd.nextDouble() * 0.3;
    _tapImpulses.add((t, intensity));
    if (_tapImpulses.length > 8) _tapImpulses.removeAt(0);

    final boxH = math.min(.23 * size.height, 196.0);
    final top = size.height - boxH;
    final treeX = (70.0 / 400.0) * size.width;
    final treeY = top + 83.6 * boxH / 100.0;
    final u = boxH / 100.0;
    final s = u * 0.8;

    // Water ripple at the shore foot
    _ripples.add(
      _WaterRipple(
        pos: Offset(treeX + (_rnd.nextDouble() * 20 - 10) * s, treeY - 2 * s),
        color: isDay ? const Color(0x60FFFFFF) : const Color(0x40A0C0FF),
        spawnTime: t,
        maxRadius: 26.0,
      ),
    );

    // Easter egg: Startled bird flies out on 3 quick taps
    if (_consecutiveTaps >= 3 && _activeBird == null) {
      HapticFeedback.mediumImpact();
      _activeBird = _StartledBird(
        start: Offset(treeX + (_rnd.nextDouble() * 20 - 10) * s, treeY - 95 * s),
        spawnTime: t,
        color: isDay ? const Color(0xD01E2438) : const Color(0xC00E1020),
      );
    }

    final isSnow = scene.treeSnow > 0.04;
    final isAutumn = scene.treeFallen > 0.04 || scene.treeLeaf == 0xFFB5552C;

    // At night: startled fireflies flutter upwards
    if (!isDay) {
      final count = 5 + _rnd.nextInt(5);
      final colors = [
        const Color(0xFFE8F542),
        const Color(0xFF9EFF7A),
        const Color(0xFF64FFDA),
        const Color(0xFFFFD166),
      ];
      for (var i = 0; i < count; i++) {
        final origin = Offset(
          treeX + (_rnd.nextDouble() * 70 - 35) * s,
          treeY - (35 + _rnd.nextDouble() * 85) * s,
        );
        _fireflies.add(
          _Firefly(
            start: origin,
            vx: (_rnd.nextDouble() * 26 - 13),
            vy: -(22 + _rnd.nextDouble() * 28),
            radius: 1.8 + _rnd.nextDouble() * 1.5,
            color: colors[_rnd.nextInt(colors.length)],
            spawnTime: t + i * 0.06,
            phase: _rnd.nextDouble() * math.pi * 2,
          ),
        );
      }
    }

    // Leaves or snowflakes: flutter down
    final leafCount = isSnow ? 14 : 7 + _rnd.nextInt(4);
    for (var i = 0; i < leafCount; i++) {
      final origin = Offset(
        treeX + (_rnd.nextDouble() * 64 - 32) * s,
        treeY - (40 + _rnd.nextDouble() * 75) * s,
      );
      Color leafColor;
      if (isSnow) {
        leafColor = Colors.white.withValues(alpha: 0.75 + _rnd.nextDouble() * 0.25);
      } else if (isAutumn) {
        final tones = [
          const Color(0xFFE58F28),
          const Color(0xFFCF5822),
          const Color(0xFFB84518),
          const Color(0xFFF2B838),
        ];
        leafColor = tones[_rnd.nextInt(tones.length)];
      } else {
        final tones = [
          const Color(0xFF5AB664),
          const Color(0xFF75CB7A),
          const Color(0xFF439E4E),
          const Color(0xFF8DE085),
        ];
        leafColor = tones[_rnd.nextInt(tones.length)];
      }

      _leaves.add(
        _FallingLeaf(
          start: origin,
          vx: 12.0 + _rnd.nextDouble() * 22.0,
          vy: 24.0 + _rnd.nextDouble() * 28.0,
          len: (4.0 + _rnd.nextDouble() * 3.2) * s,
          wid: (2.2 + _rnd.nextDouble() * 1.8) * s,
          angle: _rnd.nextDouble() * math.pi * 2,
          rotSpeed: (3.0 + _rnd.nextDouble() * 5.0) * (_rnd.nextBool() ? 1 : -1),
          color: leafColor,
          spawnTime: t + i * 0.05,
          phase: _rnd.nextDouble() * math.pi * 2,
          isSnow: isSnow,
        ),
      );
    }

    notifyListeners();
  }

  /// Calculates dynamic branch sway impulse from touches.
  double rustleAt(double t) {
    if (_tapImpulses.isEmpty) return 0.0;
    _tapImpulses.removeWhere((item) => t - item.$1 > 2.6);
    double sum = 0.0;
    for (final (tapT, intensity) in _tapImpulses) {
      final dt = t - tapT;
      if (dt >= 0 && dt < 2.5) {
        // Physical spring damped harmonic oscillation
        final decay = math.exp(-dt * 2.8);
        final osc = math.sin(dt * 14.2) * decay * intensity * 2.8;
        sum += osc;
      }
    }
    return sum.clamp(-4.5, 4.5);
  }

  /// Paints interactive falling leaves, fireflies, ripples, and birds on the canvas.
  void paint(Canvas canvas, Size size, double t, bool isDay, SkyScene scene) {
    final boxH = math.min(.23 * size.height, 196.0);
    final top = size.height - boxH;
    final lakeY = top + 84.0 * boxH / 100.0;

    // 1. Water Ripples
    _ripples.removeWhere((r) => t - r.spawnTime > _WaterRipple.duration);
    for (final r in _ripples) {
      final dt = t - r.spawnTime;
      if (dt < 0) continue;
      final progress = (dt / _WaterRipple.duration).clamp(0.0, 1.0);
      final radius = 2.0 + progress * r.maxRadius;
      final alpha = (1.0 - progress) * 0.55;

      canvas.save();
      canvas.translate(r.pos.dx, r.pos.dy);
      // Perspective oval for flat water surface
      canvas.scale(1.0, 0.36);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = r.color.withValues(alpha: alpha);
      canvas.drawCircle(Offset.zero, radius, paint);
      canvas.restore();
    }

    // 2. Falling Leaves / Snowflakes
    _leaves.removeWhere((l) {
      if (l.landTime != null) return t - l.landTime! > 1.4;
      return t - l.spawnTime > 4.5;
    });

    final leafPath = Path();
    for (final leaf in _leaves) {
      final dt = t - leaf.spawnTime;
      if (dt < 0) continue;

      if (leaf.landTime == null) {
        final curX = leaf.start.dx + leaf.vx * dt + math.sin(dt * 4.2 + leaf.phase) * 14.0;
        final curY = leaf.start.dy + leaf.vy * dt;
        if (curY >= lakeY) {
          leaf.landTime = t;
          leaf.landPos = Offset(curX, lakeY + (curY - lakeY) * 0.3);
          _ripples.add(
            _WaterRipple(
              pos: leaf.landPos!,
              color: isDay ? const Color(0x50FFFFFF) : const Color(0x35A0C0FF),
              spawnTime: t,
              maxRadius: 16.0,
            ),
          );
        }
      }

      final Offset pos;
      final double alpha;
      final double curAngle;

      if (leaf.landTime != null) {
        final floatDt = t - leaf.landTime!;
        pos = Offset(leaf.landPos!.dx + floatDt * 4.0, leaf.landPos!.dy);
        alpha = (1.0 - (floatDt / 1.4)).clamp(0.0, 1.0);
        curAngle = leaf.angle + (leaf.landTime! - leaf.spawnTime) * leaf.rotSpeed;
      } else {
        final curX = leaf.start.dx + leaf.vx * dt + math.sin(dt * 4.2 + leaf.phase) * 14.0;
        final curY = leaf.start.dy + leaf.vy * dt;
        pos = Offset(curX, curY);
        alpha = (dt < 0.2 ? dt / 0.2 : 1.0).clamp(0.0, 1.0);
        curAngle = leaf.angle + dt * leaf.rotSpeed;
      }

      final leafPaint = Paint()..color = leaf.color.withValues(alpha: alpha);

      if (leaf.isSnow) {
        canvas.drawCircle(pos, leaf.len * 0.35, leafPaint);
      } else {
        leafPath.reset();
        _drawLeaf(leafPath, pos, leaf.len, leaf.wid, curAngle);
        canvas.drawPath(leafPath, leafPaint);
      }
    }

    // 3. Night Fireflies
    _fireflies.removeWhere((f) => t - f.spawnTime > 3.6);
    for (final f in _fireflies) {
      final dt = t - f.spawnTime;
      if (dt < 0) continue;
      final curX = f.start.dx + f.vx * dt + math.sin(dt * 3.4 + f.phase) * 18.0;
      final curY = f.start.dy + f.vy * dt + math.cos(dt * 2.8 + f.phase) * 8.0;
      final pos = Offset(curX, curY);

      final pulse = 0.55 + 0.45 * math.sin(dt * 8.0 + f.phase);
      final fade = dt > 2.6 ? (3.6 - dt).clamp(0.0, 1.0) : (dt < 0.3 ? dt / 0.3 : 1.0);
      final alpha = (pulse * fade).clamp(0.0, 1.0);

      final glowPaint = Paint()
        ..shader = ui.Gradient.radial(
          pos,
          f.radius * 3.8,
          [f.color.withValues(alpha: alpha * 0.75), f.color.withValues(alpha: 0.0)],
        );
      canvas.drawCircle(pos, f.radius * 3.8, glowPaint);
      canvas.drawCircle(pos, f.radius * 0.9, Paint()..color = Colors.white.withValues(alpha: alpha));
    }

    // 4. Startled Bird Easter Egg
    final bird = _activeBird;
    if (bird != null) {
      final dt = t - bird.spawnTime;
      if (dt > 4.5) {
        _activeBird = null;
      } else {
        final progress = dt / 4.5;
        // Flies diagonally up and right across the lake towards the mountains
        final curX = bird.start.dx + dt * 75.0 + math.sin(progress * math.pi) * 12.0;
        final curY = bird.start.dy - dt * 38.0 + math.sin(dt * 5.0) * 5.0;
        final c = Offset(curX, curY);

        final flap = math.sin(dt * 16.0);
        final span = (5.5 - progress * 1.5).clamp(3.0, 5.5);
        final lift = 2.4 * flap;
        final alpha = (progress > 0.85 ? (1.0 - progress) / 0.15 : 1.0).clamp(0.0, 1.0);

        final birdPath = Path()
          ..moveTo(c.dx - span, c.dy - lift)
          ..quadraticBezierTo(c.dx - span * .4, c.dy - lift * .3 - 1.2, c.dx, c.dy)
          ..quadraticBezierTo(c.dx + span * .4, c.dy - lift * .3 - 1.2, c.dx + span, c.dy - lift);

        final birdPaint = Paint()
          ..color = bird.color.withValues(alpha: alpha * 0.85)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        canvas.drawPath(birdPath, birdPaint);
      }
    }
  }
}
