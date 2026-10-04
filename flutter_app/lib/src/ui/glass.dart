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
