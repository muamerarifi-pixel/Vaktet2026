import 'package:flutter/material.dart';

import '../logic/calendar_notes.dart';
import '../logic/format.dart';
import '../logic/prayer.dart';
import '../logic/tips.dart';
import '../state/app_controller.dart';
import 'colors.dart';
import 'glass.dart';
import 'landscape.dart' show khatam;
import 'next_card.dart';
import 'sky.dart';
import 'svg_icon.dart';
import 'text.dart';
import 'widgets.dart';

const Color _white = Color(0xFFFFFFFF);

/// The Today tab: the date, the next-prayer card, the alarm suggestion and the prayer list.
class TodayPanel extends StatelessWidget {
  const TodayPanel({super.key, required this.controller, required this.clock});

  final AppController controller;
  final SkyClock? clock;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final model = c.model;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DateRow(controller: c, bottomGap: c.isToday ? 14 : 8),
        if (!c.isToday) ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PillButton(label: 'Kthehu te sot', onTap: c.selectToday),
            ),
          ),
        ],
        ...[
          NextCard(
            model: model,
            now: c.viewNow,
            mode: SkyMode.card,
            clock: clock,
            countdownWeight: c.countdownWeight,
            countdownFont: c.countdownFont.family,
            gold: model.friday && c.on(Feature.fridayLook),
          ),
          if (model.alarm != null) AlarmCard(alarm: model.alarm!),
        ],
        TimesList(model: model, now: c.viewNow),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            cityNote(c.city),
            textAlign: TextAlign.center,
            style: vt(13.5, 500, color: context.colors.muted),
          ),
        ),
        if (c.on(Feature.tips)) TipsSection(controller: c),
      ],
    );
  }
}

/// `‹  Saturday, 3 October 2026 / 22 Rebiul Ahir 1448 h.  ›`
class DateRow extends StatelessWidget {
  const DateRow({super.key, required this.controller, this.onSky = false, this.bottomGap = 14, this.onTapDate});

  final AppController controller;
  final bool onSky;
  final double bottomGap;

  /// A tap on the date (it opens the month).
  final VoidCallback? onTapDate;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final colors = context.colors;
    final hijri = c.on(Feature.hijri) ? hijriLabel(c.selected, c.hijriAdj) : '';
    final notes = DayNotes(controller: c, onSky: onSky);
    return Padding(
      padding: EdgeInsets.only(top: onSky ? 2 : 10, bottom: onSky ? 0 : bottomGap),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_dates(context, c, colors, hijri), notes],
      ),
    );
  }

  Widget _tappable(Widget child) =>
      onTapDate == null ? child : Tap(onTap: onTapDate!, label: 'Shfaq muajin', child: child);

  Widget _dates(BuildContext context, AppController c, VaktetColors colors, String hijri) {
    return Row(
      children: [
        StepButton(next: false, label: 'Dita e mëparshme', onTap: () => c.stepDay(-1), onSky: onSky),
        const SizedBox(width: 8),
        Expanded(
          child: _tappable(
            Column(
              children: [
                Text(
                  longDate(c.selected),
                  textAlign: TextAlign.center,
                  style: vt(
                    21,
                    850,
                    color: onSky ? _white : colors.ink,
                    ls: -.015,
                    height: 1.25,
                    shadows: onSky
                        ? const [Shadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 1))]
                        : null,
                  ),
                ),
                if (hijri.isNotEmpty || onTapDate != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          hijri,
                          textAlign: TextAlign.center,
                          style: vt(14.5, 650, color: onSky ? const Color(0xC7FFFFFF) : colors.muted),
                        ),
                      ),
                      // the date opens the month
                      if (onTapDate != null) ...[
                        const SizedBox(width: 5),
                        SvgIcon(VIcon.chevDown, size: 13, color: onSky ? const Color(0xB3FFFFFF) : colors.muted),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        StepButton(next: true, label: 'Dita tjetër', onTap: () => c.stepDay(1), onSky: onSky),
      ],
    );
  }
}

const Color _gold = Color(0xFFF1CF7A);

/// The colour of the dot before a note: Kosovo's blue, the green of Islam, the Takvim's silver.
Color _noteColor(NoteKind k, {required bool onSky, required VaktetColors colors}) => switch (k) {
  NoteKind.national => onSky ? const Color(0xFF8FB4FF) : const Color(0xFF2F5BC4),
  NoteKind.islamic => onSky ? const Color(0xFF7FE0B4) : colors.accent,
  NoteKind.takvim => onSky ? const Color(0xFFE2E6F0) : colors.muted,
};

/// The notes the settings let through, the most important first.
List<DayNote> shownNotes(AppController c) {
  final notes = [
    for (final n in c.model.notes)
      if ((n.kind == NoteKind.national && c.on(Feature.national)) ||
          (n.kind == NoteKind.islamic && c.on(Feature.islamic)) ||
          (n.kind == NoteKind.takvim && c.on(Feature.takvim)))
        n,
  ];
  int rank(DayNote n) => n.kind == NoteKind.islamic ? 0 : (n.holiday ? 1 : (n.kind == NoteKind.national ? 2 : 3));
  notes.sort((a, b) => rank(a).compareTo(rank(b)));
  return notes;
}

String noteText(DayNote n, {required bool today}) {
  final text = n.night ? '${today ? 'Sonte' : 'Në mbrëmje'}: ${n.text}' : n.text;
  return n.holiday && n.kind == NoteKind.national && !n.text.startsWith('Ditë pushimi')
      ? '$text · festë zyrtare'
      : text;
}

/// Under the date: the Friday greeting, and what the calendar notes for the day (national days, the great
/// Islamic nights and days, the Takvim's notes). On a short screen only the most important one.
class DayNotes extends StatelessWidget {
  const DayNotes({super.key, required this.controller, this.onSky = false});

  final AppController controller;
  final bool onSky;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final colors = context.colors;
    final friday = c.model.friday && c.on(Feature.fridayLook);
    final all = shownNotes(c);
    final short = MediaQuery.sizeOf(context).height < 700;
    final notes = all.take(onSky ? (short ? 1 : 3) : 6).toList();
    if (!friday && notes.isEmpty) return const SizedBox.shrink();
    final chips = <Widget>[
      for (final n in notes)
        _NoteChip(
          text: noteText(n, today: c.isToday),
          dot: _noteColor(n.kind, onSky: onSky, colors: colors),
          onSky: onSky,
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (friday) _FridayMark(onSky: onSky),
          if (friday && chips.isNotEmpty) const SizedBox(height: 7),
          if (chips.isNotEmpty) Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: chips),
        ],
      ),
    );
  }
}

/// Fridays: a small eight-pointed star in gold and "Xhuma mubarek", with a hairline on each side.
class _FridayMark extends StatelessWidget {
  const _FridayMark({required this.onSky});

  final bool onSky;

  @override
  Widget build(BuildContext context) {
    final gold = onSky ? _gold : const Color(0xFF9A7220);
    Widget line(bool left) => Container(
      width: 22,
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gold.withValues(alpha: 0), gold.withValues(alpha: .7)],
          begin: left ? Alignment.centerLeft : Alignment.centerRight,
          end: left ? Alignment.centerRight : Alignment.centerLeft,
        ),
      ),
    );
    return Semantics(
      label: 'E xhuma, Xhuma mubarek',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          line(true),
          const SizedBox(width: 8),
          CustomPaint(size: const Size(11, 11), painter: _KhatamPainter(gold)),
          const SizedBox(width: 7),
          Text(
            'Xhuma mubarek',
            style: vt(
              13,
              720,
              color: gold,
              ls: .04,
              height: 1.3,
              shadows: onSky ? const [Shadow(color: Color(0x59000000), blurRadius: 8, offset: Offset(0, 1))] : null,
            ),
          ),
          const SizedBox(width: 8),
          line(false),
        ],
      ),
    );
  }
}

class _KhatamPainter extends CustomPainter {
  _KhatamPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      khatam(size.center(Offset.zero), size.shortestSide / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_KhatamPainter old) => old.color != color;
}

class _NoteChip extends StatelessWidget {
  const _NoteChip({required this.text, required this.dot, required this.onSky});

  final String text;
  final Color dot;
  final bool onSky;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = onSky ? const Color(0xF2FFFFFF) : colors.ink;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: vt(12.5, 720, color: fg, height: 1.3),
          ),
        ),
      ],
    );
    const padding = EdgeInsets.fromLTRB(10, 4, 12, 4);
    if (onSky) {
      return Glass(
        fill: const Color(0x1FFFFFFF),
        border: const Color(0x33FFFFFF),
        blur: 10,
        padding: padding,
        child: row,
      );
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: colors.surface,
        border: Border.all(color: colors.line),
      ),
      child: row,
    );
  }
}

/// The day's two tips.
class TipsSection extends StatelessWidget {
  const TipsSection({super.key, required this.controller, this.onSky = false});

  final AppController controller;

  /// Inside the dark prayer-times sheet of the full-screen sky.
  final bool onSky;

  @override
  Widget build(BuildContext context) {
    final tips = tipsFor(controller.selected);
    return Padding(
      padding: EdgeInsets.only(top: onSky ? 10 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: onSky ? 12 : 4),
            child: Text(
              controller.isToday ? 'DY KËSHILLA PËR SOT' : 'DY KËSHILLA PËR KËTË DITË',
              style: onSky
                  ? vt(12.5, 800, color: const Color(0xC7FFFFFF), ls: .08, height: 1.4)
                  : vt(13, 800, ls: .06, height: 1.5, color: context.colors.muted),
            ),
          ),
          SizedBox(height: onSky ? 6 : 10),
          for (var i = 0; i < tips.length; i++) ...[
            if (i > 0) SizedBox(height: onSky ? 6 : 10),
            onSky ? _SkyTipCard(tip: tips[i]) : _TipCard(tip: tips[i]),
          ],
        ],
      ),
    );
  }
}

/// A tip on the dark sheet of the full-screen sky.
class _SkyTipCard extends StatelessWidget {
  const _SkyTipCard({required this.tip});

  final Tip tip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${tip.tag}  ',
              style: vt(12.5, 850, color: tip.muslim ? const Color(0xFFB9E6C9) : const Color(0xFFBFD3FF), height: 1.4),
            ),
            TextSpan(text: tip.text),
          ],
        ),
        style: vt(14.5, 600, color: const Color(0xEBFFFFFF), height: 1.4),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.tip});

  final Tip tip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 17),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: tip.muslim ? c.tipMSoft : c.accentSoft,
            ),
            child: Text(tip.tag, style: vt(12.5, 800, color: tip.muslim ? c.tipM : c.accent, height: 1.5)),
          ),
          Text(tip.text, style: vt(16.5, 600, color: c.ink, height: 1.5)),
        ],
      ),
    );
  }
}

/// The suggested alarm for Sabahu.
class AlarmCard extends StatelessWidget {
  const AlarmCard({super.key, required this.alarm});

  final AlarmModel alarm;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          SvgIcon(VIcon.alarm, size: 26, color: c.accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Alarmi për sabah', style: vt(15.5, 800, color: c.ink, height: 1.5)),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(alarm.sub, style: vt(13.5, 500, color: c.muted, height: 1.35)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text(alarm.time, style: vt(28, 880, color: c.accent, ls: -.01, height: 1.5)),
        ],
      ),
    );
  }
}

/// The day's prayer times.
class TimesList extends StatelessWidget {
  const TimesList({super.key, required this.model, required this.now});

  final TodayModel model;
  final int now;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final narrow = MediaQuery.sizeOf(context).width <= 380;
    final rows = model.rows;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            _TimeRow(
              row: rows[i],
              isNext: identical(rows[i], model.nextRow),
              isPast: model.isPast(rows[i], now),
              // no divider next to the highlighted row
              divider: i > 0 && !identical(rows[i], model.nextRow) && !identical(rows[i - 1], model.nextRow),
              narrow: narrow,
            ),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.row,
    required this.isNext,
    required this.isPast,
    required this.divider,
    required this.narrow,
  });

  final PrayerRow row;
  final bool isNext;
  final bool isPast;
  final bool divider;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = isNext ? c.accent : (isPast ? c.faint : c.ink);
    final nameWeight = isNext ? 880.0 : (isPast ? 650.0 : 700.0);
    final timeWeight = isNext ? 880.0 : (isPast ? 650.0 : 800.0);
    return Semantics(
      container: true,
      label: '${row.name} ${fmtTime(row.local)}',
      excludeSemantics: true,
      selected: isNext,
      child: Stack(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: narrow ? 12 : 16, vertical: narrow ? 12 : 13),
            decoration: BoxDecoration(color: isNext ? c.accentSoft : null, borderRadius: BorderRadius.circular(14)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(row.name, style: vt(narrow ? 16 : 17, nameWeight, color: color, height: 1.5)),
                ),
                const SizedBox(width: 12),
                Text(fmtTime(row.local), style: vt(18, timeWeight, color: color, ls: .01, height: 1.5)),
              ],
            ),
          ),
          if (divider) Positioned(left: 16, right: 16, top: 0, child: Container(height: 1, color: c.line)),
        ],
      ),
    );
  }
}

/// The day's prayer times on the full-screen sky: a sheet that is swiped up from the bottom.
class SkyTimesSheet extends StatelessWidget {
  const SkyTimesSheet({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final model = c.model;
    final now = c.viewNow;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xEB0B1024),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0x2EFFFFFF)),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 30, offset: Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // the grab handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(color: const Color(0x66FFFFFF), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Text(
                  c.isToday ? 'VAKTET E SOTME' : 'VAKTET E DITËS',
                  style: vt(12.5, 800, color: const Color(0xC7FFFFFF), ls: .08, height: 1.4),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    c.city.name,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: vt(13.5, 700, color: const Color(0xC7FFFFFF), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          for (final row in model.rows)
            _SkyTimeRow(row: row, isNext: identical(row, model.nextRow), isPast: model.isPast(row, now)),
          if (model.alarm != null) _SkyAlarmRow(alarm: model.alarm!),
          _SkyNotes(controller: c),
          if (c.on(Feature.tips)) TipsSection(controller: c, onSky: true),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _SkyTimeRow extends StatelessWidget {
  const _SkyTimeRow({required this.row, required this.isNext, required this.isPast});

  final PrayerRow row;
  final bool isNext;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final color = _white.withValues(alpha: isPast ? .5 : 1);
    final weight = isNext ? 880.0 : (isPast ? 650.0 : 750.0);
    return Semantics(
      container: true,
      label: '${row.name} ${fmtTime(row.local)}',
      excludeSemantics: true,
      selected: isNext,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isNext ? const Color(0x2EFFFFFF) : null,
          borderRadius: BorderRadius.circular(14),
          border: isNext ? Border.all(color: const Color(0x33FFFFFF)) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(row.name, style: vt(16.5, weight, color: color, height: 1.4)),
            ),
            const SizedBox(width: 12),
            Text(fmtTime(row.local), style: vt(17.5, weight, color: color, ls: .01, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

/// The suggested Sabah alarm, as one line of the sheet.
class _SkyAlarmRow extends StatelessWidget {
  const _SkyAlarmRow({required this.alarm});

  final AlarmModel alarm;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        children: [
          SvgIcon(VIcon.alarm, size: 20, color: const Color(0xE6FFFFFF)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Alarmi për sabah', style: vt(14.5, 800, color: _white, height: 1.35)),
                Text(alarm.sub, style: vt(12.5, 550, color: const Color(0xB3FFFFFF), height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(alarm.time, style: vt(20, 880, color: _white, height: 1.3)),
        ],
      ),
    );
  }
}

/// Every note of the day, in the sheet (the home screen shows only the first ones).
class _SkyNotes extends StatelessWidget {
  const _SkyNotes({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final notes = shownNotes(controller);
    if (notes.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 9),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final n in notes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _noteColor(n.kind, onSky: true, colors: context.colors),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      noteText(n, today: controller.isToday),
                      style: vt(14, 680, color: const Color(0xEBFFFFFF), height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

final TextStyle _hintStyle = vt(
  13,
  700,
  color: const Color(0xD1FFFFFF),
  height: 1.3,
  shadows: const [Shadow(color: Color(0x59000000), blurRadius: 8, offset: Offset(0, 1))],
);

/// "Swipe up for the prayer times", with a chevron that stays still.
class SwipeHint extends StatelessWidget {
  const SwipeHint({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      label: 'Shfaq vaktet e sotme',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgIcon(VIcon.chevUp, size: 18, color: const Color(0xE6FFFFFF)),
            Text('Rrëshqit lart për vaktet', style: _hintStyle),
          ],
        ),
      ),
    );
  }
}

/// The Sabah alarm on the sky itself, from Jacia until Imsaku.
class HomeAlarm extends StatelessWidget {
  const HomeAlarm({super.key, required this.alarm});

  final AlarmModel alarm;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Alarmi për sabah ${alarm.time}, ${alarm.sub}',
      excludeSemantics: true,
      child: Glass(
        radius: 18,
        blur: 12,
        fill: const Color(0x1FFFFFFF),
        border: const Color(0x38FFFFFF),
        padding: const EdgeInsets.fromLTRB(12, 7, 14, 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgIcon(VIcon.alarm, size: 20, color: const Color(0xF2FFFFFF)),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Alarmi për sabah', style: vt(13.5, 800, color: _white, height: 1.3)),
                  Text(
                    alarm.sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: vt(11.5, 600, color: const Color(0xC7FFFFFF), height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(alarm.time, style: vt(22, 880, color: _white, height: 1.2)),
          ],
        ),
      ),
    );
  }
}

/// A line in small letters at the bottom of the sky: when Sabahu can be prayed, a voluntary prayer whose time it
/// is, the prayer after a forbidden time.
class SmallLine extends StatelessWidget {
  const SmallLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 2,
      style: vt(
        12,
        650,
        color: const Color(0xC2FFFFFF),
        height: 1.3,
        shadows: const [Shadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 1))],
      ),
    ),
  );
}
