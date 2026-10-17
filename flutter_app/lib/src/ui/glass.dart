import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A frosted-glass shape: translucent fill and a hairline border.
///
/// It sits on the animated sky, which is soft enough that a live backdrop blur adds almost nothing to the look,
/// while it would have to be redone on every frame. So the glass is drawn as a tint, a little stronger than the
/// blurred version, which keeps the sky smooth.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 999,
    this.fill = const Color(0x26FFFFFF),
    this.border = const Color(0x3DFFFFFF),
    this.blur = 10,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double radius;
  final Color fill;
  final Color border;

  /// How frosted the glass looks: a stronger blur reads as a slightly denser tint.
  final double blur;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    // stand-in for the blur: a faint dark wash under the white tint, denser for a stronger blur
    final frost = Color.fromRGBO(10, 14, 30, (blur / 14 * .10).clamp(0.0, .12));
    return DecoratedBox(
      decoration: BoxDecoration(color: frost, borderRadius: shape),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: shape,
          border: Border.all(color: border),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Real frosted glass, for the countdown and the times on the sky: the sky behind is blurred and a little more
/// vivid, under a light wash that is brighter at the top left, with an edge that catches the light.
///
/// [live] blurs what is behind; without it (while the glass fades out, where a blur can't see the sky) the same
/// glass is drawn as a denser tint. The widgets are the same either way, so switching never builds what is on
/// the glass again. Glass under a [BackdropGroup] shares one picture of the sky with the other glass there.
class FrostedGlass extends StatelessWidget {
  const FrostedGlass({
    super.key,
    required this.child,
    this.live = true,
    this.radius = 28,
    this.sigma = 18,
    this.padding = EdgeInsets.zero,
    this.gold = false,
    this.tint,
  });

  final Widget child;
  final bool live;

  /// A colour laid under the glass's light wash, so what is on it reads over any sky (the prayer-times sheet).
  final Color? tint;
  final double radius;
  final double sigma;
  final EdgeInsetsGeometry padding;

  /// Fridays: the edge glows gold, like the digits.
  final bool gold;

  // saturate(1.35): the blurred sky behind the glass keeps its colour instead of turning grey
  static const double _s = 1.35;
  static const ui.ColorFilter _vivid = ui.ColorFilter.matrix(<double>[
    .2126 * (1 - _s) + _s, .7152 * (1 - _s), .0722 * (1 - _s), 0, 0, //
    .2126 * (1 - _s), .7152 * (1 - _s) + _s, .0722 * (1 - _s), 0, 0,
    .2126 * (1 - _s), .7152 * (1 - _s), .0722 * (1 - _s) + _s, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter.grouped(
        enabled: live,
        filter: ui.ImageFilter.compose(
          outer: _vivid,
          inner: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        ),
        child: DecoratedBox(
          // without the blur, a soft dark wash stands in for it
          decoration: BoxDecoration(
            color: live ? tint : Color.alphaBlend(const Color(0x1F0A0E1E), tint ?? const Color(0x00000000)),
            borderRadius: shape,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: shape,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: live
                    ? const [Color(0x33FFFFFF), Color(0x14FFFFFF), Color(0x0AFFFFFF)]
                    : const [Color(0x40FFFFFF), Color(0x24FFFFFF), Color(0x1AFFFFFF)],
                stops: const [0, .55, 1],
              ),
            ),
            child: CustomPaint(
              foregroundPainter: _GlassEdge(radius: radius, gold: gold),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// The frosted glass of the prayer-times sheet: the same glass, under a dark tint so the times read over any sky.
class SheetGlass extends FrostedGlass {
  const SheetGlass({
    super.key,
    required super.child,
    super.radius,
    super.sigma,
    super.padding,
    super.tint = const Color(0x730B1024),
  });
}

/// The glass's rim: bright where the light falls (top left), fading along the sides, with a little light again
/// at the bottom right, and a fine highlight just inside the top edge.
class _GlassEdge extends CustomPainter {
  const _GlassEdge({required this.radius, required this.gold});

  final double radius;
  final bool gold;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius)).deflate(.6);
    final light = gold ? const Color(0xB3F4D58D) : const Color(0x99FFFFFF);
    final mid = gold ? const Color(0x26E9C46A) : const Color(0x1FFFFFFF);
    final end = gold ? const Color(0x4DE9C46A) : const Color(0x40FFFFFF);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [light, mid, end],
          stops: const [0, .5, 1],
        ).createShader(rect),
    );
    // the sheen along the top, inside the rim
    final top = Rect.fromLTWH(radius * .6, 1.6, size.width - radius * 1.2, 1);
    canvas.drawRect(
      top,
      Paint()
        ..shader = LinearGradient(
          colors: [const Color(0x00FFFFFF), light.withValues(alpha: light.a * .55), const Color(0x00FFFFFF)],
        ).createShader(top),
    );
  }

  @override
  bool shouldRepaint(_GlassEdge old) => old.radius != radius || old.gold != gold;
}
