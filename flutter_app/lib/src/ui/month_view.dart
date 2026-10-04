import 'package:flutter/material.dart';

import '../logic/day.dart';
import '../logic/format.dart';
import '../logic/prayer.dart';
import '../state/app_controller.dart';
import 'colors.dart';
import 'text.dart';
import 'widgets.dart';

/// The Month tab: one table with all the days of the month.
class MonthPanel extends StatelessWidget {
  const MonthPanel({super.key, required this.controller, required this.onPick});

  final AppController controller;

  /// Called after a day has been chosen.
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final colors = context.colors;
    final narrow = MediaQuery.sizeOf(context).width <= 560;
    final y = c.cursorY, m = c.cursorM;
    final days = Day.daysInMonth(y, m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 14),
          child: Row(
            children: [
              StepButton(next: false, label: 'Muaji i mëparshëm', onTap: () => c.stepMonth(-1)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  monthTitle(y, m),
                  textAlign: TextAlign.center,
                  style: vt(21, 850, color: colors.ink, ls: -.015, height: 1.5),
                ),
              ),
              const SizedBox(width: 8),
              StepButton(next: true, label: 'Muaji tjetër', onTap: () => c.stepMonth(1)),
            ],
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.line),
          ),
          child: Column(
            children: [
              _HeaderRow(narrow: narrow),
              for (var d = 1; d <= days; d++)
                _DayRow(
                  day: Day(y, m, d),
                  last: d == days,
                  narrow: narrow,
                  controller: c,
                  onTap: () {
                    c.select(Day(y, m, d));
                    onPick();
                  },
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: Text(
            'Kolona e drekës tregon hyrjen e kohës. Dreka falet në 12:00 në dimër dhe në 13:00 në verë.',
            textAlign: TextAlign.center,
            style: vt(13, 500, color: colors.muted),
          ),
        ),
      ],
    );
  }
}

const _full = ['Imsaku', 'Sabahu', 'Lindja', 'Hyrja e drekës', 'Ikindia', 'Akshami', 'Jacia'];
const _abbr = ['Ims.', 'Sab.', 'Lin.', 'Dre.', 'Iki.', 'Aks.', 'Jac.'];

// Column widths. On a phone the day column is a fixed width and the seven times share the rest;
// on a wider screen they are shares of the table (the dhuhr column has the longer heading).
const double _phoneDayWidth = 36;
int _dayFlex(bool narrow) => narrow ? 0 : 24;
int _timeFlex(bool narrow, int i) => narrow ? 1 : (i == 3 ? 38 : 24);

/// The first column (the day).
Widget _dayCell(bool narrow, Widget child) =>
    narrow ? SizedBox(width: _phoneDayWidth, child: child) : Expanded(flex: _dayFlex(narrow), child: child);

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.narrow});

  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = vt(narrow ? 11.5 : 12.5, 750, color: c.muted, height: 1.5);
    return Container(
      padding: EdgeInsets.fromLTRB(narrow ? 10 : 16, narrow ? 11 : 12, narrow ? 8 : 16, narrow ? 9 : 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          _dayCell(narrow, Text('Dita', style: style)),
          for (var i = 0; i < 7; i++)
            Expanded(
              flex: _timeFlex(narrow, i),
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(narrow ? _abbr[i] : _full[i], style: style, softWrap: false),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.last,
    required this.narrow,
    required this.controller,
    required this.onTap,
  });

  final Day day;
  final bool last;
  final bool narrow;
  final AppController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isToday = day == controller.today;
    final isSelected = day == controller.selected;
    final friday = day.weekday == 5;
    final times = dayTimes(day, controller.city);

    final textColor = isToday ? c.accent : c.ink;
    final cellStyle = vt(narrow ? 12.5 : 14, isToday ? 850 : (narrow ? 680 : 660), color: textColor, height: 1.5);
    final dayColor = isToday || friday ? c.accent : c.ink;
    final underline = isSelected && !isToday;
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${weekdayNames[day.weekday]}, ${day.d} ${monthNames[day.m - 1]}',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(narrow ? 10 : 16, 8, narrow ? 8 : 16, 8),
          decoration: BoxDecoration(
            color: isToday ? c.accentSoft : null,
            border: last
                ? null
                : Border(
                    bottom: underline ? BorderSide(color: c.accent, width: 2) : BorderSide(color: c.line),
                  ),
          ),
          child: Row(
            children: [
              _dayCell(
                narrow,
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${day.d}',
                        style: vt(narrow ? 12.5 : 14, 800, color: dayColor, height: 1.5),
                      ),
                      TextSpan(
                        text: '${narrow ? '  ' : ' '}${weekdayShort[day.weekday]}',
                        style: vt(narrow ? 11 : 12.5, 660, color: isToday ? c.accent : c.muted, height: 1.5),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
              for (var i = 0; i < 7; i++)
                Expanded(
                  flex: _timeFlex(narrow, i),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(fmtTime(times[i].local), style: cellStyle, softWrap: false),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
