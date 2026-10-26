import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../logic/prayer.dart';
import 'glass.dart';
import 'sky.dart';
import 'svg_icon.dart';
import 'text.dart';
import 'widgets.dart';

const Color _white = Color(0xFFFFFFFF);

const List<Shadow> _introShadow = [
  Shadow(color: Color(0x38000000), offset: Offset(0, 1), blurRadius: 2),
  Shadow(color: Color(0x47000000), offset: Offset(0, 1), blurRadius: 10),
];
const List<Shadow> _nameShadow = [
  Shadow(color: Color(0x2E000000), offset: Offset(0, 1), blurRadius: 3),
  Shadow(color: Color(0x38000000), offset: Offset(0, 2), blurRadius: 16),
];
const List<Shadow> _countShadow = [
  Shadow(color: Color(0x38000000), offset: Offset(0, 2), blurRadius: 24),
  Shadow(color: Color(0x1F000000), offset: Offset(0, 1), blurRadius: 2),
];
const List<Shadow> _countShadowFull = [
  Shadow(color: Color(0x47000000), offset: Offset(0, 2), blurRadius: 30),
  Shadow(color: Color(0x29000000), offset: Offset(0, 1), blurRadius: 3),
];

/// The "next prayer" card: the sky with the prayer's name, time and a big countdown.
class NextCard extends StatelessWidget {
  const NextCard({
    super.key,
    required this.model,
    required this.time,
    required this.mode,
    required this.clock,
    this.reveal,
    this.options = const SkyOptions(),
    this.countdownWeight = 900,
    this.countdownFont,
    this.gold = false,
    this.countdownSize = 1.0,
  });

  /// The countdown's own font (null: the app's font).
  final String? countdownFont;

  /// The countdown is gold (Fridays).
  final bool gold;

  /// Full screen: how big the countdown is (1 = normal).
  final double countdownSize;

  /// What the sky shows (picked in the settings).
  final SkyOptions options;

  final TodayModel model;

  /// The moment shown, every second: only the countdowns are built again with it.
  final ValueListenable<int> time;
  final SkyMode mode;
  final SkyClock? clock;

  /// Full screen only: how far the prayer-times sheet is open (0–1). The countdown moves up out of its way.
  final Animation<double>? reveal;

  /// Thickness of the countdown digits (picked in the settings).
  final int countdownWeight;

  @override
  Widget build(BuildContext context) {
    final card = model.card!;
    final width = MediaQuery.sizeOf(context).width;
    final content = switch (mode) {
      SkyMode.card => _Normal(
        model: model,
        card: card,
        time: time,
        vw: width,
        weight: countdownWeight,
        family: countdownFont,
        gold: gold,
      ),
      SkyMode.full => _FullScreen(
        card: card,
        time: time,
        vw: width,
        weight: countdownWeight,
        reveal: reveal,
        family: countdownFont,
        gold: gold,
        scale: countdownSize,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: SkyCard(
        model: model,
        mode: mode,
        clock: clock,
        options: options,
        now: () => time.value,
        child: content,
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.card, required this.center, this.full = false});

  final NextCardModel card;
  final bool center;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      card.intro.toUpperCase(),
      style: vt(
        full ? 13 : 12.5,
        800,
        color: _white,
        ls: full ? .16 : .12,
        opacity: card.forbidden ? 1 : .9,
        shadows: _introShadow,
      ),
    );
    final row = card.forbidden
        ? Glass(
            blur: 10,
            fill: const Color(0x24FFFFFF),
            border: const Color(0x47FFFFFF),
            padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgIcon(VIcon.forbid, size: 15, color: _white),
                const SizedBox(width: 7),
                Flexible(child: text),
              ],
            ),
          )
        : text;
    return Align(alignment: center ? Alignment.center : Alignment.centerLeft, child: row);
  }
}

class _NameAndTime extends StatelessWidget {
  const _NameAndTime({required this.card, required this.vw, required this.center, this.full = false});

  final NextCardModel card;
  final double vw;
  final bool center;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final name = Text(
      card.name,
      softWrap: false,
      style: vt(
        full ? clampPx(30, vw * .086, 40) : clampPx(25, vw * .068, 31),
        860,
        color: _white,
        ls: -.02,
        height: 1.15,
        shadows: _nameShadow,
      ),
    );
    final time = Glass(
      padding: EdgeInsets.symmetric(horizontal: full ? 13 : 11, vertical: full ? 4 : 3),
      child: Text(
        card.time,
        softWrap: false,
        style: vt(full ? clampPx(17, vw * .048, 21) : clampPx(16, vw * .044, 19), 800, color: _white, ls: .02),
      ),
    );
    // when a prayer time comes, the next one's name and time fade in
    return FadeSwap(
      value: '${card.name} ${card.time}',
      duration: const Duration(milliseconds: 900),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: center ? WrapAlignment.center : WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: center ? (full ? 14 : 14) : 12,
          runSpacing: full ? 10 : 6,
          children: [name, time],
        ),
      ),
    );
  }
}

class _CurrentPrayerPill extends StatelessWidget {
  const _CurrentPrayerPill({required this.text, this.center = true});

  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final pill = Glass(
      blur: 10,
      fill: const Color(0x2EFFFFFF),
      border: const Color(0x3DFFFFFF),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF68D391),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: vt(12.5, 700, color: _white, ls: .04),
          ),
        ],
      ),
    );
    return Align(alignment: center ? Alignment.center : Alignment.centerLeft, child: pill);
  }
}

/// The metallic gold of the Friday countdown: light, deep and light again, like polished gold.
const LinearGradient _goldShine = LinearGradient(
  begin: Alignment(-1, -1),
  end: Alignment(1, 1),
  colors: [Color(0xFFFFF4CF), Color(0xFFF0CB6E), Color(0xFFB98A2E), Color(0xFFF7E2A0), Color(0xFFD4A445)],
  stops: [0, .32, .52, .72, 1],
);

/// The widest digit of a font at a size (and the phone's text size), so every digit can sit in a cell of the
/// same width.
final Map<String, double> _digitWidths = {};

double _widestDigit(TextStyle style, TextScaler scaler) {
  final key =
      '${style.fontFamily}/${style.fontSize}/${style.fontVariations}/${style.letterSpacing}/${scaler.scale(100)}';
  return _digitWidths[key] ??= () {
    var widest = 0.0;
    for (var d = 0; d < 10; d++) {
      final tp = TextPainter(
        text: TextSpan(text: '$d', style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      widest = widest < tp.width ? tp.width : widest;
      tp.dispose();
    }
    return widest;
  }();
}

/// The big `HH:MM:SS`: the hours and minutes large, the seconds smaller beside them, the colons a touch softer.
/// Each digit sits in a cell of the same width, so the numbers never jump, and when it changes it fades softly
/// into the next one. In a font of its own (picked in the settings), and on Fridays in gold.
class CountdownNumber extends StatelessWidget {
  const CountdownNumber({
    super.key,
    required this.text,
    required this.size,
    required this.weight,
    required this.center,
    this.full = false,
    this.family,
    this.gold = false,
  });

  /// The seconds' size next to the hours and minutes.
  static const double secondsScale = .5;

  /// How long a digit takes to fade into the next one.
  static const Duration fade = Duration(milliseconds: 450);

  /// `HH:MM:SS`.
  final String text;
  final double size;
  final int weight;
  final bool center;
  final bool full;

  /// The countdown's own font, or null for the app's font.
  final String? family;

  /// Polished gold (Fridays).
  final bool gold;

  @override
  Widget build(BuildContext context) {
    var base = vt(
      size,
      weight.toDouble(),
      color: _white,
      ls: family == null ? (full ? -.03 : -.025) : 0,
      height: 1,
      shadows: gold
          ? const [Shadow(color: Color(0x66E9C46A), blurRadius: 18)]
          : (full ? _countShadowFull : _countShadow),
    );
    if (family != null) {
      base = base.copyWith(
        fontFamily: family,
        fontFeatures: const [FontFeature.liningFigures(), FontFeature.tabularFigures()],
      );
    } else {
      // the app's font, from the theme, so the cells are measured in the font the digits are drawn in
      base = base.copyWith(fontFamily: DefaultTextStyle.of(context).style.fontFamily);
    }
    final scaler = MediaQuery.textScalerOf(context);
    final small = base.copyWith(
      fontSize: size * secondsScale,
      letterSpacing: (base.letterSpacing ?? 0) * secondsScale,
      shadows: gold ? base.shadows : (full ? _countShadow : null),
    );
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : fade;
    Widget digits(String part, TextStyle style) {
      final cell = _widestDigit(style, scaler);
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [for (final d in part.split('')) _FadeDigit(digit: d, style: style, width: cell, duration: duration)],
      );
    }

    Widget colon(TextStyle style) => Padding(
      padding: EdgeInsets.symmetric(horizontal: style.fontSize! * (family == null ? .01 : .04)),
      // the font sets its colon low, for small letters: raised to the middle of the digits, its two dots sit
      // evenly between their top and their bottom
      child: Transform.translate(
        offset: Offset(0, -style.fontSize! * .1),
        child: Text(':', style: style.copyWith(color: const Color(0x8CFFFFFF))),
      ),
    );

    final parts = text.split(':');
    Widget number = Semantics(
      label: text,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          for (var i = 0; i < parts.length; i++) ...[
            if (i > 0) colon(i < parts.length - 1 ? base : small),
            digits(parts[i], i < parts.length - 1 ? base : small),
          ],
        ],
      ),
    );
    if (gold) {
      number = ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => _goldShine.createShader(bounds),
        child: number,
      );
    }
    return FittedBox(fit: BoxFit.scaleDown, alignment: center ? Alignment.center : Alignment.centerLeft, child: number);
  }
}

/// One digit of the countdown in its cell: when it changes, the old one fades out as the new one fades in, on
/// every refresh of the screen.
///
/// The two digits stand in the same places at rest and while they fade, so a fade only changes how see-through
/// they are: nothing is built or laid out again on its frames.
class _FadeDigit extends StatefulWidget {
  const _FadeDigit({required this.digit, required this.style, required this.width, required this.duration});

  final String digit;
  final TextStyle style;
  final double width;
  final Duration duration;

  @override
  State<_FadeDigit> createState() => _FadeDigitState();
}

class _FadeDigitState extends State<_FadeDigit> with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(vsync: this, duration: widget.duration, value: 1)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && _old != null) setState(() => _old = null);
    });
  late final Animation<double> _in = CurvedAnimation(parent: _fade, curve: Curves.easeOut);
  late final Animation<double> _out = ReverseAnimation(CurvedAnimation(parent: _fade, curve: Curves.easeIn));
  late final Animation<Offset> _inSlide = Tween<Offset>(
    begin: const Offset(0, -0.15),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic));
  late final Animation<Offset> _outSlide = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(0, 0.15),
  ).animate(CurvedAnimation(parent: _fade, curve: Curves.easeInCubic));

  /// The digit fading out, while it fades.
  String? _old;

  @override
  void didUpdateWidget(_FadeDigit old) {
    super.didUpdateWidget(old);
    if (old.digit == widget.digit) return;
    if (widget.duration == Duration.zero) {
      _old = null;
      _fade.value = 1;
      return;
    }
    // a digit that changes again while it is still fading starts a new fade from the one now shown
    _old = old.digit;
    _fade.duration = widget.duration;
    _fade.forward(from: 0);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  Text _text(String d) => Text(d, style: widget.style, textAlign: TextAlign.center, softWrap: false);

  @override
  Widget build(BuildContext context) {
    final old = _old;
    return SizedBox(
      width: widget.width,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Anchors the alphabetic baseline permanently so sliding transitions
          // never jitter or vertically displace neighboring digits or the row.
          Opacity(
            opacity: 0,
            child: _text('8'),
          ),
          if (old != null)
            SlideTransition(
              position: _outSlide,
              child: FadeTransition(opacity: _out, child: _text(old)),
            ),
          SlideTransition(
            position: _inSlide,
            child: FadeTransition(opacity: _in, child: _text(widget.digit)),
          ),
        ],
      ),
    );
  }
}

class _CountdownLabel extends StatelessWidget {
  const _CountdownLabel({required this.text, this.full = false});

  final String text;
  final bool full;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: vt(full ? 15 : 14.5, 700, color: _white, opacity: .86, ls: full ? .02 : 0),
  );
}

class _Alt extends StatelessWidget {
  const _Alt({required this.card, required this.time});

  final NextCardModel card;
  final ValueListenable<int> time;

  @override
  Widget build(BuildContext context) {
    final base = vt(14.5, 650, color: _white, height: 1.4);
    return Glass(
      radius: 16,
      blur: 12,
      fill: const Color(0x24FFFFFF),
      border: const Color(0x38FFFFFF),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${card.altText} '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: ValueListenableBuilder(
                valueListenable: time,
                builder: (context, now, _) =>
                    Text(fmtCount(card.altTarget! - now), style: vt(14.5, 880, color: _white, ls: .01, height: 1.4)),
              ),
            ),
          ],
        ),
        style: base,
      ),
    );
  }
}

// ---------- Normal card ----------

class _Normal extends StatelessWidget {
  const _Normal({
    required this.model,
    required this.card,
    required this.time,
    required this.vw,
    required this.weight,
    this.family,
    this.gold = false,
  });

  final TodayModel model;
  final NextCardModel card;
  final ValueListenable<int> time;
  final double vw;
  final int weight;
  final String? family;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final pad = vw <= 380 ? 18.0 : 22.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, vw <= 380 ? 18 : 22, pad, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (card.currentPrayerText != null) ...[
            _CurrentPrayerPill(text: card.currentPrayerText!, center: false),
            const SizedBox(height: 8),
          ],
          _Intro(card: card, center: false),
          const SizedBox(height: 6),
          _NameAndTime(card: card, vw: vw, center: false),
          const SizedBox(height: 10),
          ValueListenableBuilder(
            valueListenable: time,
            builder: (context, now, _) => CountdownNumber(
              text: fmtCount(card.target - now),
              size: clampPx(54, vw * .16, 74),
              weight: weight,
              center: false,
              family: family,
              gold: gold,
            ),
          ),
          const SizedBox(height: 6),
          _CountdownLabel(text: card.countdownLabel),
          const SizedBox(height: 16),
          if (card.altText != null) ...[_Alt(card: card, time: time), const SizedBox(height: 14)],
          // the line moves once a minute, with the rest of the card
          _Dayline(model: model, now: time.value),
        ],
      ),
    );
  }
}

/// The day as a line: the prayers as ticks, and a dot for now.
class _Dayline extends StatelessWidget {
  const _Dayline({required this.model, required this.now});

  final TodayModel model;
  final int now;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: 18,
      width: double.infinity,
      child: CustomPaint(painter: _DaylinePainter(model.rows, now, model.dayFraction)),
    ),
  );
}

class _DaylinePainter extends CustomPainter {
  _DaylinePainter(this.rows, this.now, this.fraction);

  final List<PrayerRow> rows;
  final int now;
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final track = Paint()..color = const Color(0x40FFFFFF);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 8, w, 2), const Radius.circular(2)), track);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 8, w * fraction, 2), const Radius.circular(2)),
      Paint()..color = _white,
    );
    for (final r in rows) {
      final x = r.local / 1440 * w;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x - 1, 4, 2, 10), const Radius.circular(2)),
        Paint()..color = Color.fromRGBO(255, 255, 255, r.instant <= now ? .9 : .45),
      );
    }
    final x = w * fraction;
    canvas.drawCircle(Offset(x, 9), 10, Paint()..color = const Color(0x38FFFFFF));
    canvas.drawCircle(Offset(x, 9), 6, Paint()..color = _white);
  }

  @override
  bool shouldRepaint(_DaylinePainter old) => old.now != now || old.fraction != fraction || old.rows != rows;
}

// ---------- Full-screen sky ----------

/// The countdown sits exactly in the middle of the screen, with the prayer's name above it.
class _FullScreen extends StatelessWidget {
  const _FullScreen({
    required this.card,
    required this.time,
    required this.vw,
    required this.weight,
    this.reveal,
    this.family,
    this.gold = false,
    this.scale = 1.0,
  });

  final NextCardModel card;
  final ValueListenable<int> time;
  final double vw;
  final int weight;
  final Animation<double>? reveal;
  final String? family;
  final bool gold;

  /// How big the countdown is (1 = normal), from the settings.
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, box) {
          final size = (box.maxWidth * .205 * scale).clamp(0.0, 124.0 * scale);
          final number = ValueListenableBuilder(
            valueListenable: time,
            builder: (context, now, _) => CountdownNumber(
              text: fmtCount(card.target - now),
              size: size,
              weight: weight,
              center: true,
              full: true,
              family: family,
              gold: gold,
            ),
          );
          final layout = Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (card.currentPrayerText != null) ...[
                  _CurrentPrayerPill(text: card.currentPrayerText!, center: true),
                  const SizedBox(height: 14),
                ],
                _Intro(card: card, center: true, full: true),
                const SizedBox(height: 8),
                _NameAndTime(card: card, vw: vw, center: true, full: true),
                const SizedBox(height: 16),
                number,
                const SizedBox(height: 10),
                reveal == null
                    ? _CountdownLabel(text: card.countdownLabel, full: true)
                    : FadeTransition(
                        opacity: Tween(
                          begin: 1.0,
                          end: 0.0,
                        ).animate(CurvedAnimation(parent: reveal!, curve: const Interval(0, .6))),
                        child: _CountdownLabel(text: card.countdownLabel, full: true),
                      ),
              ],
            ),
          );
          final r = reveal;
          if (r == null) return layout;
          // While the prayer times are swiped up, it moves up out of their way as one finished picture. It is only
          // moved, never shrunk: the screen then keeps the soft shadows of its text from frame to frame, instead
          // of blurring them all again at every new size. And it is the same widget at rest and moving, so
          // nothing in it is built again when a swipe starts or ends.
          return AnimatedBuilder(
            animation: r,
            child: RepaintBoundary(child: layout),
            builder: (context, child) =>
                Transform.translate(offset: Offset(0, -box.maxHeight * .2 * r.value), child: child),
          );
        },
      ),
    );
  }
}
