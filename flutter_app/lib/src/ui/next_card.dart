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
    required this.now,
    required this.mode,
    required this.clock,
    this.countdownWeight = 900,
  });

  final TodayModel model;
  final int now;
  final SkyMode mode;
  final SkyClock? clock;

  /// Thickness of the countdown digits (picked in the settings).
  final int countdownWeight;

  @override
  Widget build(BuildContext context) {
    final card = model.card!;
    final width = MediaQuery.sizeOf(context).width;
    final content = switch (mode) {
      SkyMode.card => _Normal(model: model, card: card, now: now, vw: width, weight: countdownWeight),
      SkyMode.focus => _Centered(card: card, now: now, vw: width, weight: countdownWeight),
      SkyMode.full => _FullScreen(card: card, now: now, vw: width, weight: countdownWeight),
    };
    // Hiding or showing the prayer times: the card changes height smoothly while its content cross-fades.
    final animated = mode == SkyMode.full
        ? content
        : AnimatedSize(
            duration: motion(context),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: motion(context),
              switchInCurve: const Interval(.3, 1, curve: Curves.easeOut),
              switchOutCurve: const Interval(.5, 1, curve: Curves.easeIn),
              // the old content does not hold the card open; the card takes the new content's height
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topCenter,
                children: [
                  for (final p in previous) Positioned(left: 0, right: 0, top: 0, child: p),
                  ?current,
                ],
              ),
              child: KeyedSubtree(key: ValueKey(mode), child: content),
            ),
          );
    return Semantics(
      liveRegion: true,
      child: SkyCard(model: model, mode: mode, clock: clock, child: animated),
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
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: center ? WrapAlignment.center : WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: center ? (full ? 14 : 14) : 12,
        runSpacing: full ? 10 : 6,
        children: [name, time],
      ),
    );
  }
}

/// The big `HH:MM:SS`: digits at full strength, the colons a touch softer.
class _CountdownNumber extends StatelessWidget {
  const _CountdownNumber({
    required this.text,
    required this.size,
    required this.weight,
    required this.center,
    this.full = false,
  });

  final String text;
  final double size;
  final int weight;
  final bool center;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final base = vt(
      size,
      weight.toDouble(),
      color: _white,
      ls: full ? -.03 : -.025,
      height: 1,
      shadows: full ? _countShadowFull : _countShadow,
    );
    final parts = text.split(':');
    final spans = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) {
        spans.add(
          TextSpan(
            text: ':',
            style: base.copyWith(color: const Color(0x8CFFFFFF)),
          ),
        );
      }
      spans.add(TextSpan(text: parts[i]));
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: center ? Alignment.center : Alignment.centerLeft,
      child: Text.rich(TextSpan(children: spans), style: base, softWrap: false, maxLines: 1),
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
  const _Alt({required this.card, required this.now, this.center = false});

  final NextCardModel card;
  final int now;
  final bool center;

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
            TextSpan(
              text: fmtCount(card.altTarget! - now),
              style: vt(14.5, 880, color: _white, ls: .01, height: 1.4),
            ),
          ],
        ),
        style: base,
        textAlign: center ? TextAlign.center : TextAlign.start,
      ),
    );
  }
}

// ---------- Normal card ----------

class _Normal extends StatelessWidget {
  const _Normal({required this.model, required this.card, required this.now, required this.vw, required this.weight});

  final TodayModel model;
  final NextCardModel card;
  final int now;
  final double vw;
  final int weight;

  @override
  Widget build(BuildContext context) {
    final pad = vw <= 380 ? 18.0 : 22.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, vw <= 380 ? 18 : 22, pad, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Intro(card: card, center: false),
          const SizedBox(height: 6),
          _NameAndTime(card: card, vw: vw, center: false),
          const SizedBox(height: 10),
          _CountdownNumber(
            text: fmtCount(card.target - now),
            size: clampPx(54, vw * .16, 74),
            weight: weight,
            center: false,
          ),
          const SizedBox(height: 6),
          _CountdownLabel(text: card.countdownLabel),
          const SizedBox(height: 16),
          if (card.altText != null) ...[_Alt(card: card, now: now), const SizedBox(height: 14)],
          _Dayline(model: model, now: now),
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

// ---------- Centred card (prayer list hidden) ----------

class _Centered extends StatelessWidget {
  const _Centered({required this.card, required this.now, required this.vw, required this.weight});

  final NextCardModel card;
  final int now;
  final double vw;
  final int weight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 52, 18, 30),
      child: LayoutBuilder(
        builder: (context, box) {
          // `min(104px, 19cqi)`: the digits fill the card's width
          final size = (box.maxWidth * .19).clamp(0.0, 104.0);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Intro(card: card, center: true),
              const SizedBox(height: 6),
              _NameAndTime(card: card, vw: vw, center: true),
              const SizedBox(height: 14),
              _CountdownNumber(text: fmtCount(card.target - now), size: size, weight: weight, center: true),
              const SizedBox(height: 6),
              _CountdownLabel(text: card.countdownLabel),
              SizedBox(height: card.altText != null ? 14 : 4),
              if (card.altText != null) _Alt(card: card, now: now, center: true),
            ],
          );
        },
      ),
    );
  }
}

// ---------- Full-screen sky ----------

/// The countdown sits exactly in the middle of the screen; the prayer name above it, the extra line below.
class _FullScreen extends StatelessWidget {
  const _FullScreen({required this.card, required this.now, required this.vw, required this.weight});

  final NextCardModel card;
  final int now;
  final double vw;
  final int weight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, box) {
          final size = (box.maxWidth * .205).clamp(0.0, 124.0);
          return Column(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Intro(card: card, center: true, full: true),
                        const SizedBox(height: 10),
                        _NameAndTime(card: card, vw: vw, center: true, full: true),
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CountdownNumber(
                    text: fmtCount(card.target - now),
                    size: size,
                    weight: weight,
                    center: true,
                    full: true,
                  ),
                  // the label hangs below the digits without taking room, so the digits stay centred
                  SizedBox(
                    height: 0,
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      minHeight: 0,
                      maxHeight: 80,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _CountdownLabel(text: card.countdownLabel, full: true),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 64),
                    child: card.altText == null
                        ? null
                        : ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 380),
                            child: _Alt(card: card, now: now, center: true),
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
