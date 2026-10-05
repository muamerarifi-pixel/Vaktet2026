import 'package:flutter/material.dart';

/// A tiny SVG path parser (M L H V C S Q T A Z, absolute and relative) — enough to reuse the web app's
/// icon paths verbatim.
Path parseSvgPath(String d) {
  final tokens = RegExp(r'([MmLlHhVvCcSsQqTtAaZz])|(-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  final path = Path();
  var i = 0;
  var cx = 0.0, cy = 0.0, sx = 0.0, sy = 0.0;
  var lastCtrl = const Offset(0, 0); // last control point, for S/T
  var lastCmd = '';
  double num() => double.parse(tokens[i++]);
  bool isNum() => i < tokens.length && !RegExp(r'^[A-Za-z]$').hasMatch(tokens[i]);

  while (i < tokens.length) {
    var cmd = tokens[i++];
    final rel = cmd == cmd.toLowerCase();
    final up = cmd.toUpperCase();
    if (up == 'Z') {
      path.close();
      cx = sx;
      cy = sy;
      lastCmd = 'Z';
      continue;
    }
    var first = true;
    do {
      switch (up) {
        case 'M':
          var x = num(), y = num();
          if (rel) {
            x += cx;
            y += cy;
          }
          if (first) {
            path.moveTo(x, y);
            sx = x;
            sy = y;
          } else {
            path.lineTo(x, y);
          }
          cx = x;
          cy = y;
        case 'L':
          var x = num(), y = num();
          if (rel) {
            x += cx;
            y += cy;
          }
          path.lineTo(x, y);
          cx = x;
          cy = y;
        case 'H':
          var x = num();
          if (rel) x += cx;
          path.lineTo(x, cy);
          cx = x;
        case 'V':
          var y = num();
          if (rel) y += cy;
          path.lineTo(cx, y);
          cy = y;
        case 'C':
          var x1 = num(), y1 = num(), x2 = num(), y2 = num(), x = num(), y = num();
          if (rel) {
            x1 += cx;
            y1 += cy;
            x2 += cx;
            y2 += cy;
            x += cx;
            y += cy;
          }
          path.cubicTo(x1, y1, x2, y2, x, y);
          lastCtrl = Offset(x2, y2);
          cx = x;
          cy = y;
        case 'S':
          var x2 = num(), y2 = num(), x = num(), y = num();
          if (rel) {
            x2 += cx;
            y2 += cy;
            x += cx;
            y += cy;
          }
          final smooth = lastCmd == 'C' || lastCmd == 'S';
          final x1 = smooth ? 2 * cx - lastCtrl.dx : cx;
          final y1 = smooth ? 2 * cy - lastCtrl.dy : cy;
          path.cubicTo(x1, y1, x2, y2, x, y);
          lastCtrl = Offset(x2, y2);
          cx = x;
          cy = y;
        case 'Q':
          var x1 = num(), y1 = num(), x = num(), y = num();
          if (rel) {
            x1 += cx;
            y1 += cy;
            x += cx;
            y += cy;
          }
          path.quadraticBezierTo(x1, y1, x, y);
          lastCtrl = Offset(x1, y1);
          cx = x;
          cy = y;
        case 'T':
          var x = num(), y = num();
          if (rel) {
            x += cx;
            y += cy;
          }
          final smooth = lastCmd == 'Q' || lastCmd == 'T';
          final x1 = smooth ? 2 * cx - lastCtrl.dx : cx;
          final y1 = smooth ? 2 * cy - lastCtrl.dy : cy;
          path.quadraticBezierTo(x1, y1, x, y);
          lastCtrl = Offset(x1, y1);
          cx = x;
          cy = y;
        case 'A':
          final rx = num(), ry = num(), rot = num();
          final large = num() != 0, sweep = num() != 0;
          var x = num(), y = num();
          if (rel) {
            x += cx;
            y += cy;
          }
          path.arcToPoint(
            Offset(x, y),
            radius: Radius.elliptical(rx, ry),
            rotation: rot,
            largeArc: large,
            clockwise: sweep,
          );
          cx = x;
          cy = y;
        default:
          throw FormatException('Unsupported path command $cmd in "$d"');
      }
      lastCmd = up;
      first = false;
      cmd = up;
    } while (isNum());
  }
  return path;
}

/// An icon drawn from SVG-style shapes in a square `viewBox`.
class VIcon {
  VIcon._(this.box, this.shapes, this.stroke, this.filled);

  final double box;
  final List<Path> shapes;
  final double stroke;
  final bool filled;

  factory VIcon.stroked(double box, double stroke, List<Object> parts) => VIcon._(box, _build(parts), stroke, false);
  factory VIcon.filled(double box, List<Object> parts) => VIcon._(box, _build(parts), 0, true);

  static List<Path> _build(List<Object> parts) => [for (final p in parts) p is Path ? p : parseSvgPath(p as String)];

  static Path circle(double cx, double cy, double r) =>
      Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
  static Path rrect(double x, double y, double w, double h, double r) =>
      Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)));

  // The web app's icons, with the same paths.
  // the logo: a crescent opening upwards with a star above it (the same as the app icon)
  static final brand = VIcon.filled(32, [
    'M6.816 12.293A10 10 0 1 0 25.184 12.293A9.2 9.2 0 0 1 6.816 12.293Z',
    'M16 5.75Q16.8 8.95 20 9.75Q16.8 10.55 16 13.75Q15.2 10.55 12 9.75Q15.2 8.95 16 5.75Z',
  ]);
  static final settings = VIcon.stroked(24, 1.7, [
    circle(12, 12, 3),
    'M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1Z',
  ]);
  static final stepPrev = VIcon.stroked(16, 1.7, ['M10 3.5 5.5 8l4.5 4.5']);
  static final stepNext = VIcon.stroked(16, 1.7, ['M6 3.5 10.5 8 6 12.5']);
  static final chevDown = VIcon.stroked(16, 1.6, ['M4 6l4 4 4-4']);
  static final chevUp = VIcon.stroked(16, 1.6, ['M4 10l4-4 4 4']);
  static final forbid = VIcon.stroked(16, 1.6, [circle(8, 8, 6.3), 'M3.6 12.4 12.4 3.6']);
  static final hide = VIcon.stroked(24, 1.9, [
    'M3 3l18 18M10.6 5.1A10.4 10.4 0 0 1 12 5c5.5 0 9 5.5 9 7 0 .7-.8 2.2-2.2 3.7M6.5 6.6C4.3 8 3 10.9 3 12c0 1.5 3.5 7 9 7 1.9 0 3.6-.6 5-1.5M9.9 9.9a3 3 0 0 0 4.2 4.2',
  ]);
  static final show = VIcon.stroked(24, 1.9, [
    'M3 12c0-1.5 3.5-7 9-7s9 5.5 9 7-3.5 7-9 7-9-5.5-9-7Z',
    circle(12, 12, 3),
  ]);
  static final check = VIcon.stroked(24, 2.2, ['M5 12.5l4.5 4.5L19 7.5']);
  static final close = VIcon.stroked(24, 1.8, ['M6 6l12 12M18 6 6 18']);
  static final alarm = VIcon.stroked(24, 1.7, [circle(12, 13, 7.5), 'M12 9.5V13l2.5 1.5M4.5 5 7 3M19.5 5 17 3']);
  static final tabToday = VIcon.stroked(24, 1.7, [circle(12, 12, 8.5), 'M12 7.5V12l3 2']);
  static final tabMonth = VIcon.stroked(24, 1.7, [rrect(3.5, 5, 17, 15.5, 2.5), 'M3.5 10h17M8 3v4M16 3v4']);
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.color);

  final VIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / icon.box;
    canvas.scale(scale);
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = icon.filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = icon.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final path in icon.shapes) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) => old.icon != icon || old.color != color;
}

class SvgIcon extends StatelessWidget {
  const SvgIcon(this.icon, {super.key, required this.size, required this.color});

  final VIcon icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _IconPainter(icon, color)),
  );
}
