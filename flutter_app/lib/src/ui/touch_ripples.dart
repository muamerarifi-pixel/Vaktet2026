import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/prayer.dart';
import 'colors.dart' show SkyPalette, skyPalettes;
import 'sky.dart' show SkyClock;

class _SkyRipple {
  const _SkyRipple({
    required this.center,
    required this.spawnTime,
    required this.duration,
    required this.startRadius,
    required this.maxRadius,
    required this.deep,
  });

  final Offset center;
  final double spawnTime;
  final double duration;
  final double startRadius;
  final double maxRadius;
  final bool deep;
}

class _HoldBreath {
  _HoldBreath({
    required this.pointer,
    required this.downPos,
    required this.pos,
    required this.downTime,
    required this.haptics,
    required this.isTreeTap,
  });

  final int pointer;
  final Offset downPos;
  Offset pos;
  final double downTime;
  final bool haptics;
  final bool isTreeTap;
  bool isBreath = false;
  double breathStartTime = 0.0;
}

/// Manages serene, stress-relief Atmospheric Sky-Rings across the home screen:
/// - Quick tap: blooms 3 whisper-soft concentric luminous rings with a delicate inner glow
/// - Calm Hold-to-Breathe: holding still gently swells a 4s breathing halo that releases into a deeper wave
/// - Zero idle frame cost: holds `SkyClock.shared` only while ripples or a hold are active
class TouchRipples extends ChangeNotifier {
  TouchRipples._();

  static final TouchRipples shared = TouchRipples._();

  static const int _maxRipples = 12;
  static const double _moveCancelThreshold = 18.0;
  static const Duration _holdDelay = Duration(milliseconds: 240);

  final List<_SkyRipple> _ripples = [];
  _HoldBreath? _activeHold;
  Timer? _holdTimer;
  bool _clockHeld = false;

  /// Whether any ripple or breathing halo is currently active.
  bool get hasActive => _ripples.isNotEmpty || _activeHold != null;

  /// Number of currently active expanding ripples (exposed for tests).
  int get activeRippleCount => _ripples.length;

  /// Whether a calm hold-to-breathe halo is currently active (exposed for tests).
  bool get isHoldingBreath => _activeHold?.isBreath ?? false;

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
    _ripples.removeWhere((r) => t - r.spawnTime > r.duration + 0.40);
    if (_ripples.isEmpty && _activeHold == null) {
      _releaseClock();
      notifyListeners();
      return;
    }
    notifyListeners();
  }

  /// Begins tracking a screen touch for tap ripple or calm hold-to-breathe.
  void pointerDown(
    int pointer,
    Offset pos, {
    bool haptics = true,
    bool isTreeTap = false,
  }) {
    _holdTimer?.cancel();
    final t = SkyClock.shared.seconds;
    _activeHold = _HoldBreath(
      pointer: pointer,
      downPos: pos,
      pos: pos,
      downTime: t,
      haptics: haptics,
      isTreeTap: isTreeTap,
    );
    _ensureClock();

    _holdTimer = Timer(_holdDelay, () {
      final h = _activeHold;
      if (h == null || h.pointer != pointer) return;
      h.isBreath = true;
      h.breathStartTime = SkyClock.shared.seconds;
      if (h.haptics) HapticFeedback.selectionClick();
      notifyListeners();
    });

    notifyListeners();
  }

  /// Tracks fingertip movement; cancels the hold gracefully if the user starts swiping.
  void pointerMove(int pointer, Offset pos) {
    final h = _activeHold;
    if (h == null || h.pointer != pointer) return;
    if ((pos - h.downPos).distance > _moveCancelThreshold) {
      _holdTimer?.cancel();
      _activeHold = null;
      notifyListeners();
      return;
    }
    h.pos = pos;
  }

  /// Completes a touch: launches either quick concentric sky-rings or a deep breath-release wave.
  void pointerUp(int pointer) {
    final h = _activeHold;
    if (h == null || h.pointer != pointer) return;
    _holdTimer?.cancel();
    _activeHold = null;

    final t = SkyClock.shared.seconds;
    if (h.isBreath) {
      final releaseR = _breathRadiusAt(h, t);
      if (h.haptics) HapticFeedback.lightImpact();
      _addRipple(
        _SkyRipple(
          center: h.pos,
          spawnTime: t,
          duration: 2.85,
          startRadius: releaseR,
          maxRadius: releaseR + 158.0,
          deep: true,
        ),
      );
    } else {
      if (h.haptics && !h.isTreeTap) HapticFeedback.selectionClick();
      _addRipple(
        _SkyRipple(
          center: h.pos,
          spawnTime: t,
          duration: 2.20,
          startRadius: 6.0,
          maxRadius: 118.0,
          deep: false,
        ),
      );
    }
    _ensureClock();
    notifyListeners();
  }

  /// Cancels an active pointer without firing a release burst.
  void pointerCancel(int pointer) {
    final h = _activeHold;
    if (h == null || h.pointer != pointer) return;
    _holdTimer?.cancel();
    _activeHold = null;
    notifyListeners();
  }

  /// Clears all active ripples (e.g. when toggled off in Settings or on sheet open).
  void clear() {
    _holdTimer?.cancel();
    _activeHold = null;
    if (_ripples.isEmpty) return;
    _ripples.clear();
    _releaseClock();
    notifyListeners();
  }

  void _addRipple(_SkyRipple ripple) {
    if (_ripples.length >= _maxRipples) {
      _ripples.removeAt(0);
    }
    _ripples.add(ripple);
  }

  static double _breathRadiusAt(_HoldBreath h, double t) {
    final dt = math.max(0.0, t - h.breathStartTime);
    final intro = (dt / 0.45).clamp(0.0, 1.0);
    final introEased = 1.0 - math.pow(1.0 - intro, 2.2);
    // Calm 4.0-second inhale/exhale cycle
    final breath = 0.5 - 0.5 * math.cos(dt * math.pi / 2.0);
    return (16.0 + introEased * 16.0) + breath * 34.0;
  }

  /// Derives soothing luminous ring colors from the live sky palette.
  static ({Color ring, Color glow, Color core}) paletteFor(SkyPhase phase, {bool dark = false}) {
    final SkyPalette? pal = skyPalettes[phase];
    final stars = pal?.stars ?? 0.5;

    final Color ring;
    final Color glow;
    final Color core;
    if (stars >= 0.65) {
      // Night: serene moonlit silver-blue
      ring = const Color(0xFFB8D4FA);
      glow = const Color(0xFF8CB4EA);
      core = const Color(0xFFEAF3FF);
    } else if (stars >= 0.12 || phase == SkyPhase.dawn || phase == SkyPhase.dusk) {
      // Dawn / Sunrise / Dusk: warm amber-peach twilight glow
      final sunTint = pal?.sun ?? const Color(0xFFFFCA8A);
      ring = Color.lerp(const Color(0xFFFFCA8A), sunTint, 0.28)!;
      glow = const Color(0xFFFFA864);
      core = const Color(0xFFFFF2DE);
    } else {
      // Daytime: soft sunlit ivory-gold
      ring = const Color(0xFFFFF6E4);
      glow = const Color(0xFFFFE4B5);
      core = const Color(0xFFFFFFFF);
    }

    if (dark) {
      return (
        ring: Color.lerp(ring, const Color(0xFF101824), 0.12)!,
        glow: Color.lerp(glow, const Color(0xFF101824), 0.14)!,
        core: Color.lerp(core, const Color(0xFFDCE6F4), 0.10)!,
      );
    }
    return (ring: ring, glow: glow, core: core);
  }

  /// Paints all active Atmospheric Sky-Rings and any active Calm Hold-to-Breathe halo.
  void paint(Canvas canvas, Size size, double t, SkyPhase phase, {bool dark = false}) {
    final colors = paletteFor(phase, dark: dark);

    // 1. Expanding Atmospheric Sky-Rings
    _ripples.removeWhere((r) => t - r.spawnTime > r.duration + 0.40);
    for (final r in _ripples) {
      final dt = t - r.spawnTime;
      if (dt < 0) continue;

      final baseProgress = (dt / r.duration).clamp(0.0, 1.0);
      final baseEased = 1.0 - math.pow(1.0 - baseProgress, 2.6);

      // Soft inner radial mist that blooms gently and dissolves
      final glowRadius = r.startRadius + baseEased * (r.maxRadius - r.startRadius) * 0.72;
      final glowAlpha = math.pow(1.0 - baseProgress, 1.85) * (r.deep ? 0.22 : 0.16);
      if (glowAlpha > 0.003 && glowRadius > 1.0) {
        final mistPaint = Paint()
          ..shader = ui.Gradient.radial(
            r.center,
            glowRadius,
            [
              colors.core.withValues(alpha: glowAlpha * 0.75),
              colors.glow.withValues(alpha: glowAlpha * 0.42),
              colors.glow.withValues(alpha: 0.0),
            ],
            const [0.0, 0.48, 1.0],
          );
        canvas.drawCircle(r.center, glowRadius, mistPaint);
      }

      // 3 staggered whisper-soft concentric luminous rings
      const delays = [0.0, 0.16, 0.34];
      const radiusScales = [1.0, 0.80, 0.60];
      const alphaWeights = [1.0, 0.74, 0.50];

      for (var i = 0; i < 3; i++) {
        final rDt = dt - delays[i];
        if (rDt <= 0) continue;
        final ringDur = r.duration * (1.0 - i * 0.06);
        if (rDt > ringDur) continue;

        final p = (rDt / ringDur).clamp(0.0, 1.0);
        final eased = 1.0 - math.pow(1.0 - p, 3.0);
        final radius = r.startRadius + eased * (r.maxRadius - r.startRadius) * radiusScales[i];

        final fadeIn = (p < 0.08 ? p / 0.08 : 1.0);
        final fadeOut = math.pow(1.0 - p, 1.65);
        final ringAlpha = (fadeIn * fadeOut * (r.deep ? 0.56 : 0.46) * alphaWeights[i]).clamp(0.0, 1.0);
        if (ringAlpha <= 0.004) continue;

        final strokeW = (r.deep ? 1.65 : 1.35) * (1.0 - p * 0.58) * (1.0 - i * 0.12);

        // Soft luminous outer halo stroke (zero-blur GPU-friendly bloom)
        final haloPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW + 3.2
          ..color = colors.glow.withValues(alpha: ringAlpha * 0.24);
        canvas.drawCircle(r.center, radius, haloPaint);

        // Crisp whisper-thin luminous ring
        final ringPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..color = colors.ring.withValues(alpha: ringAlpha);
        canvas.drawCircle(r.center, radius, ringPaint);
      }
    }

    // 2. Active Touch Mist & Calm Hold-to-Breathe Halo
    final hold = _activeHold;
    if (hold != null) {
      final downDt = math.max(0.0, t - hold.downTime);
      if (!hold.isBreath) {
        // Immediate whisper-soft contact glow before hold threshold
        final p = (downDt / 0.24).clamp(0.0, 1.0);
        final r = 8.0 + p * 14.0;
        final a = p * 0.20;
        final touchPaint = Paint()
          ..shader = ui.Gradient.radial(
            hold.pos,
            r,
            [colors.core.withValues(alpha: a), colors.glow.withValues(alpha: 0.0)],
          );
        canvas.drawCircle(hold.pos, r, touchPaint);
      } else {
        final breathDt = math.max(0.0, t - hold.breathStartTime);
        final intro = (breathDt / 0.45).clamp(0.0, 1.0);
        final breath = 0.5 - 0.5 * math.cos(breathDt * math.pi / 2.0);
        final radius = _breathRadiusAt(hold, t);

        // Breathing luminous mist
        final mistAlpha = intro * (0.14 + 0.10 * breath);
        final mistPaint = Paint()
          ..shader = ui.Gradient.radial(
            hold.pos,
            radius * 1.15,
            [
              colors.core.withValues(alpha: mistAlpha * 0.85),
              colors.glow.withValues(alpha: mistAlpha * 0.45),
              colors.glow.withValues(alpha: 0.0),
            ],
            const [0.0, 0.52, 1.0],
          );
        canvas.drawCircle(hold.pos, radius * 1.15, mistPaint);

        // Soft halo bloom + primary breathing ring
        final primaryAlpha = intro * (0.38 + 0.18 * breath);
        canvas.drawCircle(
          hold.pos,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.6
            ..color = colors.glow.withValues(alpha: primaryAlpha * 0.24),
        );
        canvas.drawCircle(
          hold.pos,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = colors.ring.withValues(alpha: primaryAlpha),
        );

        // Delicate outer echo ring floating gently ahead of the breath
        final echoAlpha = intro * (0.18 + 0.10 * breath);
        canvas.drawCircle(
          hold.pos,
          radius * 1.24,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.85
            ..color = colors.ring.withValues(alpha: echoAlpha),
        );
      }
    }
  }
}

/// CustomPainter for [TouchRipples] that repaints only while ripples or a breath hold are active.
class TouchRipplePainter extends CustomPainter {
  TouchRipplePainter({required this.phase, required this.dark}) : super(repaint: TouchRipples.shared);

  final SkyPhase phase;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (!TouchRipples.shared.hasActive) return;
    TouchRipples.shared.paint(canvas, size, SkyClock.shared.seconds, phase, dark: dark);
  }

  @override
  bool shouldRepaint(TouchRipplePainter old) => old.phase != phase || old.dark != dark;
}
