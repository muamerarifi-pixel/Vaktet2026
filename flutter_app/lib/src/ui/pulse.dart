import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A quiet sign that a prayer time has come: when the countdown reaches its target, a soft ring of light spreads
/// out across the sky from the countdown and fades. No sound, nothing to dismiss.
class PrayerPulse extends StatefulWidget {
  const PrayerPulse({super.key, required this.target, required this.now, this.enabled = true});

  /// What the countdown runs to (epoch milliseconds); null when there is none.
  final int? target;
  final int now;

  /// Off when the phone asks for less motion.
  final bool enabled;

  @override
  State<PrayerPulse> createState() => PrayerPulseState();
}

class PrayerPulseState extends State<PrayerPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  /// Whether the pulse is running (for tests).
  bool get running => _c.isAnimating;

  @override
  void didUpdateWidget(PrayerPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    final was = oldWidget.target;
    // the countdown moved on because its time came (not because the city or the day changed)
    if (widget.enabled && was != null && widget.target != was && widget.now >= was && widget.now - was < 5000) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => _c.value == 0 || _c.value == 1
              ? const SizedBox.expand()
              : CustomPaint(size: Size.infinite, painter: _PulsePainter(_c.value)),
        ),
      ),
    ),
  );
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.v);

  final double v;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final reach = math.sqrt(size.width * size.width + size.height * size.height) / 2;
    final p = Curves.easeOutCubic.transform(v);
    final fade = 1 - Curves.easeIn.transform(v);
    // a soft wash of light over the whole sky, strongest at the start
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color.fromRGBO(255, 248, 230, .08 * math.sin(math.pi * math.min(1, v * 2))),
    );
    // the ring spreading out
    final r = reach * (.08 + .95 * p);
    final band = .16;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = ui.Gradient.radial(
          c,
          r,
          [const Color(0x00FFF4DC), Color.fromRGBO(255, 244, 220, .32 * fade), const Color(0x00FFF4DC)],
          [math.max(0, 1 - band * 2), 1 - band * .6, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.v != v;
}
