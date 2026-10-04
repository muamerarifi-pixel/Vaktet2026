import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../logic/prayer.dart';
import '../logic/tips.dart';
import '../state/app_controller.dart';
import 'colors.dart';
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
    final focusOn = c.focusOn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DateRow(controller: c, bottomGap: model.isToday ? 14 : 8),
        if (!model.isToday) ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PillButton(label: 'Kthehu te sot', onTap: c.selectToday),
            ),
          ),
        ],
        if (model.isToday) ...[
          NextCard(model: model, now: c.now, mode: focusOn ? SkyMode.focus : SkyMode.card, clock: clock),
          BelowCard(controller: c),
          if (!focusOn && model.alarm != null) AlarmCard(alarm: model.alarm!),
        ],
        if (!focusOn) ...[
          TimesList(model: model, now: c.now),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              cityNote(c.city),
              textAlign: TextAlign.center,
              style: vt(13.5, 500, color: context.colors.muted),
            ),
          ),
        ],
      ],
    );
  }
}

/// `‹  Saturday, 3 October 2026 / 22 Rebiul Ahir 1448 h.  ›`
class DateRow extends StatelessWidget {
  const DateRow({super.key, required this.controller, this.onSky = false, this.bottomGap = 14});

  final AppController controller;
  final bool onSky;
  final double bottomGap;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final colors = context.colors;
    final hijri = hijriText(c.selected, c.hijriAdj);
    return Padding(
      padding: EdgeInsets.only(top: onSky ? 2 : 10, bottom: onSky ? 0 : bottomGap),
      child: Row(
        children: [
          StepButton(next: false, label: 'Dita e mëparshme', onTap: () => c.stepDay(-1), onSky: onSky),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
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
                const SizedBox(height: 2),
                Text(
                  hijri.isEmpty ? ' ' : hijri,
                  textAlign: TextAlign.center,
                  style: vt(14.5, 650, color: onSky ? const Color(0xC7FFFFFF) : colors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StepButton(next: true, label: 'Dita tjetër', onTap: () => c.stepDay(1), onSky: onSky),
        ],
      ),
    );
  }
}

/// The "hide the prayer times" button, and (while they are hidden) the day's tips.
class BelowCard extends StatelessWidget {
  const BelowCard({super.key, required this.controller, this.onSky = false});

  final AppController controller;
  final bool onSky;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (!c.isToday) return const SizedBox.shrink();
    final focusOn = c.focusOn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: onSky ? 0 : 10),
        PillButton(
          label: c.focus ? 'Shfaq vaktet' : 'Fshih vaktet',
          icon: c.focus ? VIcon.show : VIcon.hide,
          onTap: c.toggleFocus,
          onSky: onSky,
          fontSize: 15,
          expand: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        ),
        if (focusOn) TipsSection(controller: c, onSky: onSky),
      ],
    );
  }
}

class TipsSection extends StatelessWidget {
  const TipsSection({super.key, required this.controller, this.onSky = false});

  final AppController controller;
  final bool onSky;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final colors = context.colors;
    final tips = tipsFor(c.today);
    return Padding(
      padding: EdgeInsets.only(top: onSky ? 12 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, (onSky || !c.tipsOn) ? 0 : 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'DY KËSHILLA PËR SOT',
                    style: vt(
                      13,
                      800,
                      ls: .06,
                      height: 1.5,
                      color: onSky ? const Color(0xD1FFFFFF) : colors.muted,
                      opacity: onSky ? null : (c.tipsOn ? 1 : .6),
                      shadows: onSky
                          ? const [Shadow(color: Color(0x59000000), blurRadius: 8, offset: Offset(0, 1))]
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                PillButton(
                  label: c.tipsOn ? 'Fshih' : 'Shfaq',
                  onTap: c.toggleTips,
                  onSky: onSky,
                  fontSize: 13.5,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  semanticsLabel: c.tipsOn ? 'Fshih këshillat' : 'Shfaq këshillat',
                ),
              ],
            ),
          ),
          if (c.tipsOn)
            for (var i = 0; i < tips.length; i++) ...[if (i > 0) const SizedBox(height: 10), _TipCard(tip: tips[i])],
        ],
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
