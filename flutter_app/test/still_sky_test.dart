// The still layers of the sky: painted once into a picture, shown as that picture on every frame.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaktet/src/ui/sky.dart';

/// Sharp stripes over a gradient, so a picture that is off by a pixel, blurred or scaled shows.
class _Stripes extends CustomPainter {
  _Stripes(this.tint);

  final Color tint;
  int paints = 0;

  @override
  void paint(Canvas canvas, Size size) {
    paints++;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [tint, const Color(0xFF0B1024)]),
    );
    final line = Paint()..color = const Color(0xFFFFFFFF);
    for (var x = 3.0; x < size.width; x += 7) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1.5, size.height), line);
    }
    canvas.drawCircle(Offset(size.width * .7, size.height * .3), 9.5, Paint()..color = const Color(0xFFFFC85A));
  }

  @override
  bool shouldRepaint(_Stripes old) => old.tint != tint;
}

void main() {
  const size = Size(120, 90);
  const ratio = 2.5;

  Widget side(Key key, Widget child) =>
      RepaintBoundary(key: key, child: SizedBox.fromSize(size: size, child: child));

  Future<List<int>> pixels(WidgetTester tester, Key key) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: ratio);
      final data = await image.toByteData();
      image.dispose();
      return data!.buffer.asUint8List();
    });
    return bytes!;
  }

  Future<void> show(WidgetTester tester, CustomPainter still, CustomPainter live) => tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(devicePixelRatio: ratio),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              side(const Key('still'), StillSky(painters: [still])),
              side(const Key('live'), CustomPaint(painter: live)),
            ],
          ),
        ),
      ),
    ),
  );

  void same(List<int> a, List<int> b) {
    expect(a.length, b.length);
    var worst = 0;
    for (var i = 0; i < a.length; i++) {
      final d = (a[i] - b[i]).abs();
      if (d > worst) worst = d;
    }
    expect(worst, lessThanOrEqualTo(3));
  }

  testWidgets('the picture is the same as painting the layer, pixel for pixel, at the screen\'s resolution', (
    tester,
  ) async {
    final still = _Stripes(const Color(0xFF6A8BD8));
    await show(tester, still, _Stripes(const Color(0xFF6A8BD8)));
    same(await pixels(tester, const Key('still')), await pixels(tester, const Key('live')));
    expect(tester.renderObject<RenderStillSky>(find.byType(StillSky)).hasPicture, isTrue);
    expect(still.paints, 1);
  });

  testWidgets('painted once, and again only when the light changes', (tester) async {
    final first = _Stripes(const Color(0xFF6A8BD8));
    await show(tester, first, _Stripes(const Color(0xFF6A8BD8)));
    // built again with a painter that paints the same: the picture stays
    final again = _Stripes(const Color(0xFF6A8BD8));
    await show(tester, again, _Stripes(const Color(0xFF6A8BD8)));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(first.paints + again.paints, 1);
    // another light: painted again, and the picture shows it
    final dusk = _Stripes(const Color(0xFFE08A5A));
    await show(tester, dusk, _Stripes(const Color(0xFFE08A5A)));
    expect(dusk.paints, 1);
    same(await pixels(tester, const Key('still')), await pixels(tester, const Key('live')));
  });
}
