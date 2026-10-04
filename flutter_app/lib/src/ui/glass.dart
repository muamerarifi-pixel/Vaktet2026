import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A frosted-glass shape: translucent fill, hairline border and a blurred backdrop.
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
  final double blur;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: shape,
            border: Border.all(color: border),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
