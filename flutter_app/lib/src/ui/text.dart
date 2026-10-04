import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';

FontWeight _nearest(double w) => FontWeight.values[((w / 100).round() - 1).clamp(0, 8)];

/// The fonts are variable fonts, so the exact CSS weights (850, 880 …) can be used.
/// [ls] is letter-spacing in em, as in the web app's CSS.
/// The family is not set here: it comes from the theme, so it follows the font picked in the settings.
TextStyle vt(
  double size,
  double weight, {
  Color? color,
  double ls = 0,
  double height = 1.5,
  List<Shadow>? shadows,
  double? opacity,
}) {
  return TextStyle(
    fontSize: size,
    fontWeight: _nearest(weight),
    fontVariations: [FontVariation('wght', weight)],
    fontFeatures: const [FontFeature.tabularFigures()],
    color: opacity != null && color != null ? color.withValues(alpha: color.a * opacity) : color,
    letterSpacing: ls * size,
    height: height,
    shadows: shadows,
    decoration: TextDecoration.none,
  );
}

/// CSS `clamp(min, pct·viewport, max)`.
double clampPx(double min, double value, double max) => value.clamp(min, max).toDouble();
