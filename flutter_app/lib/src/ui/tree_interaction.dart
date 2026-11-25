import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/prayer.dart';
import 'sky.dart' show SkyClock;

/// Botanical olive leaf drawer matching the tree in landscape.dart.
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
  final c3y = center.dy + uy * (len * 0.22) - ny * (wid * 0.48);
  final c4x = center.dx - ux * (len * 0.12) - nx * (wid * 0.55);
  final c4y = center.dy - uy * (len * 0.12) - ny * (wid * 0.55);

  path
    ..moveTo(bx, by)
    ..cubicTo(c1x, c1y, c2x, c2y, tx, ty)
    ..cubicTo(c3x, c3y, c4x, c4y, bx, by)
    ..close();
}

/// Anatomical touch zones of the lakeside olive tree.
enum TreeTouchZone { canopyPad, trunk, shoreline }

/// Live time-of-day and seasonal foliage palette sampled from the rendered tree.
class TreeLeafPalette {
  const TreeLeafPalette({
    required this.shade,
    required this.mid,
    required this.lit,
    required this.crest,
    required this.snow,
  });

  final Color shade;
  final Color mid;
  final Color lit;
  final Color crest;
  final Color snow;

  /// Fallback palette when painting without an explicit tree pass (e.g. tests or desktop tree).
  factory TreeLeafPalette.fromScene(SkyScene scene, bool isDay) {
    final leaf = Color(scene.treeLeaf);
    if (isDay) {
      final mid = leaf;
      final shade = Color.lerp(leaf, const Color(0xFF1A221C), 0.42)!;
      final lit = Color.lerp(leaf, const Color(0xFFFFF2D4), 0.26)!;
      final crest = Color.lerp(lit, const Color(0xFFFFFBE8), 0.34)!;
      return TreeLeafPalette(
        shade: shade,
        mid: mid,
        lit: lit,
        crest: crest,
        snow: const Color(0xFFEAF1FA),
      );
    }
    final shade = const Color(0xFF151C28);
    final mid = Color.lerp(shade, leaf, 0.18)!;
    final lit = Color.lerp(mid, const Color(0xFF8CA6D0), 0.26)!;
    final crest = Color.lerp(lit, const Color(0xFFC2D4F2), 0.24)!;
    return TreeLeafPalette(
      shade: shade,
      mid: mid,
      lit: lit,
      crest: crest,
      snow: const Color(0xFF9EB4D4),
    );
  }

  Color toneAt(int index) => switch (index) {
    0 => shade,
    1 => mid,
    2 => lit,
    _ => crest,
  };
}

class _CanopyPad {
  const _CanopyPad(this.center, this.rx, this.ry);
  final Offset center;
  final double rx;
  final double ry;
}

class _BranchImpulse {
  const _BranchImpulse({
    required this.tapTime,
    required this.intensity,
    required this.direction,
    required this.focus,
    required this.spread,
  });

  final double tapTime;
  final double intensity;
  final double direction;
  final Offset focus;
  final double spread;
}

class _ReedImpulse {
  const _ReedImpulse({
    required this.tapTime,
    required this.intensity,
    required this.direction,
  });

  final double tapTime;
  final double intensity;
  final double direction;
}

class _FallingLeaf {
  _FallingLeaf({
    required this.start,
    required this.popVx,
    required this.popVy,
    required this.glideVx,
    required this.glideVy,
    required this.flutterAmp,
    required this.flutterFreq,
    required this.len,
    required this.wid,
    required this.angle,
    required this.slowSpin,
    required this.tumbleSpeed,
    required this.tumblePhase,
    required this.toneIndex,
    required this.spawnTime,
    required this.phase,
    required this.isSnowDust,
    required this.baseAlpha,
  });

  final Offset start;
  final double popVx;
  final double popVy;
  final double glideVx;
  final double glideVy;
  final double flutterAmp;
  final double flutterFreq;
  final double len;
  final double wid;
  final double angle;
  final double slowSpin;
  final double tumbleSpeed;
  final double tumblePhase;
  final int toneIndex;
  final double spawnTime;
  final double phase;
  final bool isSnowDust;
  final double baseAlpha;

  double? landTime;
  Offset? landPos;
  double? landAngle;
}

/// Subtle warm amber-gold dusk/night mote (at most 1–2 active, understated).
class _AmbientMote {
  const _AmbientMote({
    required this.start,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.spawnTime,
    required this.phase,
  });

  final Offset start;
  final double vx;
  final double vy;
  final double radius;
  final double spawnTime;
  final double phase;
}

class _WaterRipple {
  const _WaterRipple({
    required this.pos,
    required this.color,
    required this.spawnTime,
    this.maxRadius = 18.0,
    this.concentric = true,
  });

  static const double duration = 1.75;

  final Offset pos;
  final Color color;
  final double spawnTime;
  final double maxRadius;
  final bool concentric;
}

class _StartledBird {
  const _StartledBird({
    required this.start,
    required this.spawnTime,
    required this.color,
  });

  final Offset start;
  final double spawnTime;
  final Color color;
}

/// Manages serene, zone-aware touch interactions on the lakeside olive tree:
/// - Localized directional spring rustle aligned to the 4 olive canopy pads
/// - Aerodynamic falling leaves inheriting the tree's live time-of-day & seasonal lighting
/// - Winter powdery snow-dust shedding from bare boughs
/// - Dedicated shoreline/reed swish & realistic concentric water ripples
/// - Understated warm dusk/night ambient mote & quiet 3-tap distant bird
class TreeInteraction extends ChangeNotifier {
  TreeInteraction._();

  static final TreeInteraction shared = TreeInteraction._();

  static const int _maxActiveLeaves = 24;
  static const double _dragK = 3.6;

  /// Exact tree-local canopy pads matching `_androidSculptedTree` in landscape.dart.
  static const List<_CanopyPad> _canopyPads = [
    _CanopyPad(Offset(-28.0, -84.0), 22.0, 14.5), // Pad 0: Upper-Left Balance
    _CanopyPad(Offset(2.0, -104.0), 27.5, 15.5), // Pad 1: Upper-Center Umbrella
    _CanopyPad(Offset(36.5, -88.0), 23.0, 14.5), // Pad 2: Upper-Right Sunward
    _CanopyPad(Offset(34.5, -52.0), 19.5, 12.0), // Pad 3: Lower-Right Lakeside
  ];

  final math.Random _rnd = math.Random();

  final List<_BranchImpulse> _tapImpulses = [];
  final List<_ReedImpulse> _reedImpulses = [];
  final List<_FallingLeaf> _leaves = [];
  final List<_AmbientMote> _motes = [];
  final List<_WaterRipple> _ripples = [];
  _StartledBird? _activeBird;

  double _lastTapTime = -10.0;
  int _consecutiveTaps = 0;
  bool _clockHeld = false;

  /// Whether any tree sway, falling leaf, mote, ripple, or bird is currently animating.
  bool get hasActive =>
      _tapImpulses.isNotEmpty ||
      _reedImpulses.isNotEmpty ||
      _leaves.isNotEmpty ||
      _motes.isNotEmpty ||
      _ripples.isNotEmpty ||
      _activeBird != null;

  void _ensureClock() {
    if (_clockHeld) return;
    _clockHeld = true;
    SkyClock.shared.hold(this);
    SkyClock.shared.addListener(_onTick);
  }

  void _releaseClock() {
    if (!_clockHeld) return;
    _clockHeld = false;
    SkyClock.shared.removeListener(_onTick);
    SkyClock.shared.release(this);
  }

  void _onTick() {
    final t = SkyClock.shared.seconds;
    _tapImpulses.removeWhere((item) => t - item.tapTime > 2.8);
    _reedImpulses.removeWhere((item) => t - item.tapTime > 2.6);
    _ripples.removeWhere((r) => t - r.spawnTime > _WaterRipple.duration);
    _leaves.removeWhere((l) {
      if (l.landTime != null) return t - l.landTime! > 1.65;
      return t - l.spawnTime > 5.2;
    });
    _motes.removeWhere((mote) => t - mote.spawnTime > 3.8);
    if (_activeBird != null && t - _activeBird!.spawnTime > 4.6) {
      _activeBird = null;
    }
    if (!hasActive) {
      _releaseClock();
      notifyListeners();
      return;
    }
    notifyListeners();
  }

  /// Clears all active tree animations and releases the clock immediately (e.g. on app pause).
  void clear() {
    final had = hasActive || _clockHeld;
    _tapImpulses.clear();
    _reedImpulses.clear();
    _leaves.clear();
    _motes.clear();
    _ripples.clear();
    _activeBird = null;
    _releaseClock();
    if (had) notifyListeners();
  }

  static ({Offset origin, double scale, double u, double lakeY}) _metrics(Size size) {
    final boxH = math.min(.23 * size.height, 196.0);
    final top = size.height - boxH;
    final u = boxH / 100.0;
    final originX = (76.0 / 400.0) * size.width;
    final originY = top + 84.4 * u;
    return (origin: Offset(originX, originY), scale: u * 0.86, u: u, lakeY: originY);
  }

  /// Classifies a screen touch into the tree's anatomical zone, or `null` if outside.
  static ({TreeTouchZone zone, int padIndex})? hitZone(Offset pos, Size size) {
    if (size.width <= 0 || size.height <= 0) return null;
    final m = _metrics(size);
    if (m.scale <= 0.001) return null;
    final local = (pos - m.origin) / m.scale;

    // 1. Check the 4 olive canopy pads (with generous +8 unit touch cushion)
    int bestPad = -1;
    double bestDist = double.infinity;
    for (var i = 0; i < _canopyPads.length; i++) {
      final pad = _canopyPads[i];
      final dx = (local.dx - pad.center.dx) / (pad.rx + 8.0);
      final dy = (local.dy - pad.center.dy) / (pad.ry + 8.0);
      final d = dx * dx + dy * dy;
      if (d <= 1.25 && d < bestDist) {
        bestDist = d;
        bestPad = i;
      }
    }
    if (bestPad >= 0) {
      return (zone: TreeTouchZone.canopyPad, padIndex: bestPad);
    }

    // 2. Check sculptural trunk corridor
    if (local.dx >= -22.0 && local.dx <= 26.0 && local.dy >= -70.0 && local.dy <= 6.0) {
      return (zone: TreeTouchZone.trunk, padIndex: -1);
    }

    // 3. Check shoreline stones, lakeside reeds & immediate water edge
    if (local.dx >= -36.0 && local.dx <= 64.0 && local.dy >= -22.0 && local.dy <= 22.0) {
      return (zone: TreeTouchZone.shoreline, padIndex: -1);
    }

    return null;
  }

  /// Returns whether a screen touch point is within any interactive zone of the tree or shore.
  static bool isTreeHit(Offset pos, Size size) => hitZone(pos, size) != null;

  /// Triggers a serene, zone-aware touch reaction on the tree or shoreline.
  void tap(Offset pos, Size size, SkyScene scene, {bool isDay = true}) {
    final hit = hitZone(pos, size);
    if (hit == null) return;

    final t = SkyClock.shared.seconds;
    final m = _metrics(size);
    final localTap = (pos - m.origin) / m.scale;

    // Wake the sky clock smoothly and release automatically once all motion settles
    _ensureClock();

    // Zone 3: Shoreline / Reeds — swish reeds & ripple water right where tapped, zero false leaves
    if (hit.zone == TreeTouchZone.shoreline) {
      HapticFeedback.selectionClick();
      final dir = localTap.dx >= 0 ? 1.0 : -1.0;
      _reedImpulses.add(_ReedImpulse(tapTime: t, intensity: 1.0 + _rnd.nextDouble() * 0.35, direction: dir));
      if (_reedImpulses.length > 6) _reedImpulses.removeAt(0);

      final rippleY = math.max(pos.dy, m.lakeY - 1.2 * m.u);
      _ripples.add(
        _WaterRipple(
          pos: Offset(pos.dx, rippleY),
          color: isDay ? const Color(0x52FFFFFF) : const Color(0x3CA8C4EE),
          spawnTime: t,
          maxRadius: 24.0,
          concentric: true,
        ),
      );
      notifyListeners();
      return;
    }

    // Canopy or Trunk tap: track gentle tap cadence for 3-tap quiet distant bird
    if (t - _lastTapTime < 1.6) {
      _consecutiveTaps++;
    } else {
      _consecutiveTaps = 1;
    }
    _lastTapTime = t;

    final isWinterDust = scene.treeSnow > 0.04 || scene.treeLeaves <= 0.05;
    final crowded = _leaves.length >= _maxActiveLeaves - 4;

    if (hit.zone == TreeTouchZone.canopyPad) {
      HapticFeedback.selectionClick();
      final pad = _canopyPads[hit.padIndex];
      // Push gently away from the touched side, softly favoring rightward lake breeze
      final rawDir = localTap.dx <= pad.center.dx ? 1.0 : -1.0;
      final dir = rawDir * 0.85 + 0.15;
      final intensity = (_consecutiveTaps > 2 ? 1.35 : 0.95) + _rnd.nextDouble() * 0.25;

      _tapImpulses.add(
        _BranchImpulse(
          tapTime: t,
          intensity: intensity,
          direction: dir,
          focus: pad.center,
          spread: 44.0,
        ),
      );
      if (_tapImpulses.length > 8) _tapImpulses.removeAt(0);

      final count = crowded ? 2 : (isWinterDust ? 6 + _rnd.nextInt(4) : 4 + _rnd.nextInt(3));
      _spawnFromPad(pad, count, t, m, dir, isWinterDust: isWinterDust, scene: scene);

      // Understated warm dusk/night mote (max 2 active, occasional)
      if (!isDay && _motes.length < 2 && _rnd.nextDouble() < 0.45) {
        final origin = m.origin + (pad.center + Offset((_rnd.nextDouble() - 0.5) * pad.rx, (_rnd.nextDouble() - 0.5) * pad.ry)) * m.scale;
        _motes.add(
          _AmbientMote(
            start: origin,
            vx: 4.0 + _rnd.nextDouble() * 8.0,
            vy: -(14.0 + _rnd.nextDouble() * 12.0),
            radius: 1.4 + _rnd.nextDouble() * 0.7,
            spawnTime: t + 0.08,
            phase: _rnd.nextDouble() * math.pi * 2,
          ),
        );
      }
    } else {
      // Trunk tap: resonant whole-crown shudder + scattered leaves from across the crown
      HapticFeedback.lightImpact();
      final dir = localTap.dx <= 4.0 ? 1.0 : -1.0;
      final intensity = (_consecutiveTaps > 2 ? 1.15 : 0.82) + _rnd.nextDouble() * 0.2;

      _tapImpulses.add(
        _BranchImpulse(
          tapTime: t,
          intensity: intensity,
          direction: dir,
          focus: const Offset(4.0, -76.0),
          spread: 140.0,
        ),
      );
      if (_tapImpulses.length > 8) _tapImpulses.removeAt(0);

      final total = crowded ? 2 : (isWinterDust ? 5 + _rnd.nextInt(3) : 3 + _rnd.nextInt(3));
      for (var i = 0; i < total; i++) {
        final pad = _canopyPads[_rnd.nextInt(_canopyPads.length)];
        _spawnFromPad(pad, 1, t + i * 0.06, m, dir * 0.6, isWinterDust: isWinterDust, scene: scene);
      }
    }

    // Quiet distant silhouette bird on 3 rapid taps
    if (_consecutiveTaps >= 3 && _activeBird == null) {
      HapticFeedback.mediumImpact();
      final birdOrigin = m.origin + const Offset(10.0, -108.0) * m.scale;
      _activeBird = _StartledBird(
        start: birdOrigin,
        spawnTime: t,
        color: isDay ? const Color(0xB81E2438) : const Color(0x980E1224),
      );
    }

    notifyListeners();
  }

  void _spawnFromPad(
    _CanopyPad pad,
    int count,
    double baseTime,
    ({Offset origin, double scale, double u, double lakeY}) m,
    double pushDir, {
    required bool isWinterDust,
    required SkyScene scene,
  }) {
    // Only spawn leaves if tree has foliage (or snow-dust in winter)
    if (!isWinterDust && scene.treeLeaves <= 0.05) return;

    for (var i = 0; i < count; i++) {
      if (_leaves.length >= _maxActiveLeaves) {
        _leaves.removeAt(0);
      }
      final a = _rnd.nextDouble() * math.pi * 2;
      final r = math.sqrt(_rnd.nextDouble()) * 0.88;
      final localPt = pad.center + Offset(math.cos(a) * pad.rx * r, math.sin(a) * pad.ry * r);
      final start = m.origin + localPt * m.scale;

      final len = isWinterDust
          ? (1.1 + _rnd.nextDouble() * 1.1) * m.scale
          : (3.1 + _rnd.nextDouble() * 1.4) * m.scale;
      final wid = len * (isWinterDust ? 1.0 : (0.36 + _rnd.nextDouble() * 0.08));

      // Gentle pop away from tap + slight upward release, settling into calm lakeward glide
      final popVx = pushDir * (14.0 + _rnd.nextDouble() * 18.0) + (_rnd.nextDouble() - 0.5) * 10.0;
      final popVy = -(6.0 + _rnd.nextDouble() * 12.0);
      final glideVx = isWinterDust
          ? 6.0 + _rnd.nextDouble() * 10.0
          : 9.0 + _rnd.nextDouble() * 15.0;
      final glideVy = isWinterDust
          ? 14.0 + _rnd.nextDouble() * 12.0
          : 19.0 + _rnd.nextDouble() * 14.0;

      // Favor mid & lit tones so leaves read crisply without looking neon
      final toneRoll = _rnd.nextDouble();
      final toneIndex = toneRoll < 0.15 ? 0 : (toneRoll < 0.55 ? 1 : (toneRoll < 0.88 ? 2 : 3));

      _leaves.add(
        _FallingLeaf(
          start: start,
          popVx: popVx,
          popVy: popVy,
          glideVx: glideVx,
          glideVy: glideVy,
          flutterAmp: isWinterDust ? 6.0 + _rnd.nextDouble() * 6.0 : 10.0 + _rnd.nextDouble() * 8.0,
          flutterFreq: isWinterDust ? 2.2 + _rnd.nextDouble() * 1.0 : 2.8 + _rnd.nextDouble() * 1.3,
          len: len,
          wid: wid,
          angle: (_rnd.nextDouble() - 0.5) * 1.2,
          slowSpin: (0.4 + _rnd.nextDouble() * 0.9) * (_rnd.nextBool() ? 1 : -1),
          tumbleSpeed: 2.6 + _rnd.nextDouble() * 2.2,
          tumblePhase: _rnd.nextDouble() * math.pi * 2,
          toneIndex: toneIndex,
          spawnTime: baseTime + i * 0.065,
          phase: _rnd.nextDouble() * math.pi * 2,
          isSnowDust: isWinterDust,
          baseAlpha: isWinterDust ? 0.55 + _rnd.nextDouble() * 0.30 : 0.92,
        ),
      );
    }
  }

  /// Overall tree sway impulse (for desktop/legacy callers and sympathetic motion).
  double rustleAt(double t) => rustleAtPoint(t, const Offset(4.0, -80.0));

  /// Spatially localized directional spring sway for a point in tree-local coordinates.
  double rustleAtPoint(double t, Offset localPt) {
    if (_tapImpulses.isEmpty) return 0.0;
    _tapImpulses.removeWhere((item) => t - item.tapTime > 2.8);
    double sum = 0.0;
    for (final imp in _tapImpulses) {
      final dt = t - imp.tapTime;
      if (dt >= 0 && dt < 2.7) {
        final d = localPt - imp.focus;
        final distSq = d.dx * d.dx + d.dy * d.dy;
        final weight = 0.24 + 0.76 * math.exp(-distSq / (2.0 * imp.spread * imp.spread));
        final decay = math.exp(-dt * 2.5);
        final osc = math.sin(dt * 12.6) * decay * imp.intensity * imp.direction * 2.5 * weight;
        sum += osc;
      }
    }
    return sum.clamp(-4.2, 4.2);
  }

  /// Dedicated lakeside reed swish (shoreline taps + gentle sympathetic tree sway).
  double reedSwayAt(double t) {
    _reedImpulses.removeWhere((item) => t - item.tapTime > 2.6);
    double sum = rustleAt(t) * 0.32;
    for (final imp in _reedImpulses) {
      final dt = t - imp.tapTime;
      if (dt >= 0 && dt < 2.5) {
        final decay = math.exp(-dt * 2.2);
        sum += math.sin(dt * 9.8) * decay * imp.intensity * imp.direction * 2.6;
      }
    }
    return sum.clamp(-4.5, 4.5);
  }

  /// Paints falling leaves/snow-dust, concentric lake ripples, subtle dusk mote, and quiet bird.
  void paint(
    Canvas canvas,
    Size size,
    double t,
    bool isDay,
    SkyScene scene, {
    TreeLeafPalette? palette,
  }) {
    final m = _metrics(size);
    final lakeY = m.lakeY;
    final pal = palette ?? TreeLeafPalette.fromScene(scene, isDay);

    // 1. Concentric Perspective Water Ripples
    _ripples.removeWhere((r) => t - r.spawnTime > _WaterRipple.duration);
    for (final r in _ripples) {
      final dt = t - r.spawnTime;
      if (dt < 0) continue;
      final progress = (dt / _WaterRipple.duration).clamp(0.0, 1.0);
      final eased = 1.0 - math.pow(1.0 - progress, 2.2);
      final radius = 1.8 + eased * r.maxRadius;
      final alpha = math.pow(1.0 - progress, 1.4) * 0.48;

      canvas.save();
      canvas.translate(r.pos.dx, r.pos.dy);
      canvas.scale(1.0, 0.34);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.95
        ..color = r.color.withValues(alpha: alpha);
      canvas.drawCircle(Offset.zero, radius, paint);

      // Subtle trailing inner ring for natural water refraction
      if (r.concentric && dt > 0.22) {
        final p2 = ((dt - 0.22) / (_WaterRipple.duration - 0.22)).clamp(0.0, 1.0);
        final e2 = 1.0 - math.pow(1.0 - p2, 2.0);
        final r2 = 1.2 + e2 * (r.maxRadius * 0.68);
        final a2 = math.pow(1.0 - p2, 1.5) * 0.30;
        paint
          ..strokeWidth = 0.75
          ..color = r.color.withValues(alpha: a2);
        canvas.drawCircle(Offset.zero, r2, paint);
      }
      canvas.restore();
    }

    // 2. Aerodynamic Falling Leaves / Winter Snow-Dust
    _leaves.removeWhere((l) {
      if (l.landTime != null) return t - l.landTime! > 1.65;
      return t - l.spawnTime > 5.2;
    });

    final leafPath = Path();
    for (final leaf in _leaves) {
      final dt = t - leaf.spawnTime;
      if (dt < 0) continue;

      final dragInt = (1.0 - math.exp(-_dragK * dt)) / _dragK;
      final flutter = math.sin(dt * leaf.flutterFreq + leaf.phase);
      final bob = math.cos(dt * leaf.flutterFreq * 2.0 + leaf.phase);

      if (leaf.landTime == null) {
        final curX = leaf.start.dx + leaf.popVx * dragInt + leaf.glideVx * dt + flutter * leaf.flutterAmp;
        final curY = leaf.start.dy + leaf.popVy * dragInt + leaf.glideVy * dt + bob * 2.0;
        if (curY >= lakeY) {
          leaf.landTime = t;
          leaf.landPos = Offset(curX, lakeY + (curY - lakeY) * 0.25);
          leaf.landAngle = leaf.angle + flutter * 0.55 + dt * leaf.slowSpin;
          if (!leaf.isSnowDust) {
            _ripples.add(
              _WaterRipple(
                pos: leaf.landPos!,
                color: isDay ? const Color(0x48FFFFFF) : const Color(0x34A8C4EE),
                spawnTime: t,
                maxRadius: 14.5,
                concentric: true,
              ),
            );
          }
        }
      }

      final Offset pos;
      final double alpha;
      final double curAngle;
      final double effWid;
      final Color leafColor;

      if (leaf.landTime != null) {
        final floatDt = t - leaf.landTime!;
        pos = Offset(leaf.landPos!.dx + floatDt * 3.2, leaf.landPos!.dy);
        alpha = ((1.0 - (floatDt / 1.65)) * leaf.baseAlpha).clamp(0.0, 1.0);
        curAngle = leaf.landAngle ?? leaf.angle;
        effWid = leaf.wid * 0.45; // Perspective-foreshortened flat on water
        leafColor = leaf.isSnowDust ? pal.snow : pal.toneAt(leaf.toneIndex);
      } else {
        final curX = leaf.start.dx + leaf.popVx * dragInt + leaf.glideVx * dt + flutter * leaf.flutterAmp;
        final curY = leaf.start.dy + leaf.popVy * dragInt + leaf.glideVy * dt + bob * 2.0;
        pos = Offset(curX, curY);
        final fadeIn = (dt < 0.18 ? dt / 0.18 : 1.0).clamp(0.0, 1.0);
        final fadeOut = dt > 4.2 ? (5.2 - dt).clamp(0.0, 1.0) : 1.0;
        alpha = (fadeIn * fadeOut * leaf.baseAlpha).clamp(0.0, 1.0);

        // Natural rocking orientation + 3D edge-on foreshortening
        curAngle = leaf.angle + flutter * 0.55 + dt * leaf.slowSpin;
        final flip = math.cos(dt * leaf.tumbleSpeed + leaf.tumblePhase);
        effWid = leaf.wid * (0.28 + 0.72 * flip.abs());

        if (leaf.isSnowDust) {
          leafColor = pal.snow;
        } else {
          final baseCol = pal.toneAt(leaf.toneIndex);
          // Subtle sunlit/moonlit glint when the leaf face turns upward
          leafColor = flip > 0.32
              ? Color.lerp(baseCol, pal.crest, ((flip - 0.32) * 0.38).clamp(0.0, 0.28))!
              : baseCol;
        }
      }

      final leafPaint = Paint()..color = leafColor.withValues(alpha: alpha);

      if (leaf.isSnowDust) {
        canvas.drawCircle(pos, leaf.len * 0.5, leafPaint);
      } else {
        leafPath.reset();
        _drawLeaf(leafPath, pos, leaf.len, effWid, curAngle);
        canvas.drawPath(leafPath, leafPaint);
      }
    }

    // 3. Understated Warm Dusk/Night Ambient Mote
    _motes.removeWhere((mote) => t - mote.spawnTime > 3.8);
    for (final mote in _motes) {
      final dt = t - mote.spawnTime;
      if (dt < 0) continue;
      final curX = mote.start.dx + mote.vx * dt + math.sin(dt * 2.4 + mote.phase) * 11.0;
      final curY = mote.start.dy + mote.vy * dt + math.cos(dt * 2.0 + mote.phase) * 5.0;
      final pos = Offset(curX, curY);

      final pulse = 0.60 + 0.40 * math.sin(dt * 4.5 + mote.phase);
      final fade = dt > 2.5 ? ((3.8 - dt) / 1.3).clamp(0.0, 1.0) : (dt < 0.45 ? dt / 0.45 : 1.0);
      final alpha = (pulse * fade * 0.65).clamp(0.0, 0.65);

      const warmAmber = Color(0xFFEAC87A);
      final glowPaint = Paint()
        ..shader = ui.Gradient.radial(
          pos,
          mote.radius * 3.6,
          [warmAmber.withValues(alpha: alpha * 0.55), warmAmber.withValues(alpha: 0.0)],
        );
      canvas.drawCircle(pos, mote.radius * 3.6, glowPaint);
      canvas.drawCircle(pos, mote.radius * 0.65, Paint()..color = const Color(0xFFFFF4D6).withValues(alpha: alpha));
    }

    // 4. Quiet Distant Silhouette Bird (3-Tap Easter Egg)
    final bird = _activeBird;
    if (bird != null) {
      final dt = t - bird.spawnTime;
      if (dt > 4.6) {
        _activeBird = null;
      } else {
        final progress = dt / 4.6;
        final curX = bird.start.dx + dt * 68.0 + math.sin(progress * math.pi) * 10.0;
        final curY = bird.start.dy - dt * 32.0 + math.sin(dt * 4.2) * 4.0;
        final c = Offset(curX, curY);

        final flap = math.sin(dt * 12.5);
        final span = (4.8 - progress * 1.6).clamp(2.6, 4.8);
        final lift = 2.0 * flap;
        final fadeIn = (dt < 0.25 ? dt / 0.25 : 1.0).clamp(0.0, 1.0);
        final fadeOut = (progress > 0.80 ? (1.0 - progress) / 0.20 : 1.0).clamp(0.0, 1.0);
        final alpha = (fadeIn * fadeOut * 0.72).clamp(0.0, 1.0);

        final birdPath = Path()
          ..moveTo(c.dx - span, c.dy - lift)
          ..quadraticBezierTo(c.dx - span * .4, c.dy - lift * .3 - 1.0, c.dx, c.dy)
          ..quadraticBezierTo(c.dx + span * .4, c.dy - lift * .3 - 1.0, c.dx + span, c.dy - lift);

        final birdPaint = Paint()
          ..color = bird.color.withValues(alpha: alpha)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        canvas.drawPath(birdPath, birdPaint);
      }
    }
  }
}
