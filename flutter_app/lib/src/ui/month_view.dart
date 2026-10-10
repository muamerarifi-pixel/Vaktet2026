import 'package:flutter/material.dart';

import '../logic/calendar_notes.dart';
import '../logic/day.dart';
import '../logic/format.dart';
import '../logic/prayer.dart';
import '../state/app_controller.dart';
import 'colors.dart';
import 'text.dart';
import 'today_view.dart' show noteText;
import 'widgets.dart';

/// Each prayer's own colour in the month, so the columns are easy to find and compare:
/// Imsaku indigo, Sabahu blue, Lindja orange, Dreka gold, Ikindia green, Akshami red, Jacia violet.
const List<(Color, Color)> _prayerColors = [
  (Color(0xFF4A4FB5), Color(0xFFA5A9FF)),
  (Color(0xFF1C73AD), Color(0xFF7EC6F4)),
  (Color(0xFFBF6400), Color(0xFFFFB45E)),
  (Color(0xFF8C7300), Color(0xFFF0D25C)),
  (Color(0xFF1B7D58), Color(0xFF70D8A9)),
  (Color(0xFFBF3A2C), Color(0xFFFF8E7E)),
  (Color(0xFF7A3EAF), Color(0xFFC99EFF)),
];

Color prayerColor(int i, bool dark) => dark ? _prayerColors[i].$2 : _prayerColors[i].$1;

const Color _holidayLight = Color(0xFFC0392B), _holidayDark = Color(0xFFFF8E7E);

/// The month: one table with all its days. The headings stay at the top while the days scroll, so the times can
/// be compared; it needs a bounded height.
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
    final marked = <(Day, List<DayNote>)>[];
    for (var d = 1; d <= days; d++) {
      final notes = _visibleNotes(c, Day(y, m, d));
      if (notes.isNotEmpty) marked.add((Day(y, m, d), notes));
    }
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
                child: Column(
                  children: [
                    Text(
                      monthTitle(y, m),
                      textAlign: TextAlign.center,
                      style: vt(21, 850, color: colors.ink, ls: -.015, height: 1.4),
                    ),
                    if (c.on(Feature.hijri)) _HijriMonths(y: y, m: m, adj: c.hijriAdj),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StepButton(next: true, label: 'Muaji tjetër', onTap: () => c.stepMonth(1)),
            ],
          ),
        ),
        // the column headings stay in place; only the days scroll under them
        Expanded(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.line),
            ),
            child: Column(
              children: [
                _HeaderRow(narrow: narrow),
                Expanded(
                  child: ListView.builder(
                    // each month starts at its first day
                    key: ValueKey('$y-$m'),
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: days + 1,
                    itemBuilder: (context, i) {
                      if (i == days) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Text(
                                'Kolona e drekës tregon hyrjen e kohës. Dreka falet në 12:00 në dimër dhe në 13:00 në verë.',
                                textAlign: TextAlign.center,
                                style: vt(13, 500, color: colors.muted),
                              ),
                            ),
                            if (marked.isNotEmpty) _MarkedDays(marked: marked, controller: c),
                            const SizedBox(height: 12),
                          ],
                        );
                      }
                      final day = Day(y, m, i + 1);
                      return _DayRow(
                        day: day,
                        last: i + 1 == days,
                        narrow: narrow,
                        controller: c,
                        onTap: () {
                          c.select(day);
                          onPick();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The notes of a day that the settings let through.
List<DayNote> _visibleNotes(AppController c, Day day) => [
  for (final n in notesFor(day, hijriAdj: c.hijriAdj, city: c.city))
    if ((n.kind == NoteKind.national && c.on(Feature.national)) ||
        (n.kind == NoteKind.islamic && c.on(Feature.islamic)) ||
        (n.kind == NoteKind.takvim && c.on(Feature.takvim)))
      n,
];

/// The Hijri months that the month spans, e.g. `Rebiul Ahir – Xhumadel Ula 1448`.
class _HijriMonths extends StatelessWidget {
  const _HijriMonths({required this.y, required this.m, required this.adj});

  final int y;
  final int m;
  final int adj;

  @override
  Widget build(BuildContext context) {
    final a = hijriOf(Day(y, m, 1), adj), b = hijriOf(Day(y, m, Day.daysInMonth(y, m)), adj);
    if (a == null || b == null) return const SizedBox.shrink();
    final first = hijriMonthNames[a.m - 1], last = hijriMonthNames[b.m - 1];
    final text = a.m == b.m ? '$first ${a.y}' : (a.y == b.y ? '$first – $last ${b.y}' : '$first ${a.y} – $last ${b.y}');
    return Text(
      text,
      textAlign: TextAlign.center,
      style: vt(13.5, 650, color: context.colors.muted, height: 1.3),
    );
  }
}

const _full = ['Imsaku', 'Sabahu', 'Lindja', 'Hyrja e drekës', 'Ikindia', 'Akshami', 'Jacia'];
const _abbr = ['Ims.', 'Sab.', 'Lin.', 'Dre.', 'Iki.', 'Aks.', 'Jac.'];

// Column widths. On a phone the day column is a fixed width and the seven times share the rest;
// on a wider screen they are shares of the table (the dhuhr column has the longer heading).
const double _phoneDayWidth = 40;
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
    return Container(
      padding: EdgeInsets.fromLTRB(narrow ? 8 : 16, narrow ? 10 : 12, narrow ? 6 : 16, narrow ? 8 : 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          _dayCell(narrow, Text('Dita', style: vt(narrow ? 11.5 : 12.5, 750, color: c.muted, height: 1.5))),
          for (var i = 0; i < 7; i++)
            Expanded(
              flex: _timeFlex(narrow, i),
              child: Align(
                alignment: Alignment.centerRight,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        narrow ? _abbr[i] : _full[i],
                        style: vt(narrow ? 11.5 : 12.5, 820, color: prayerColor(i, c.dark), height: 1.5),
                        softWrap: false,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      width: narrow ? 22 : 30,
                      height: 3,
                      decoration: BoxDecoration(color: prayerColor(i, c.dark), borderRadius: BorderRadius.circular(2)),
                    ),
                  ],
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
    final ctl = controller;
    final isToday = day == ctl.today;
    final isSelected = day == ctl.selected;
    final friday = day.weekday == 5;
    final times = dayTimes(day, ctl.city);
    final notes = _visibleNotes(ctl, day);
    final holiday = notes.any((n) => n.holiday);
    final islamic = notes.any((n) => n.kind == NoteKind.islamic);
    final hijri = ctl.on(Feature.hijri) ? hijriOf(day, ctl.hijriAdj) : null;

    final dayColor = holiday ? (c.dark ? _holidayDark : _holidayLight) : (isToday || friday ? c.accent : c.ink);
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
          padding: EdgeInsets.fromLTRB(narrow ? 8 : 16, 6, narrow ? 6 : 16, 6),
          decoration: BoxDecoration(
            color: isToday ? c.accentSoft : (friday ? c.accent.withValues(alpha: c.dark ? .07 : .045) : null),
            border: Border(
              left: BorderSide(color: isToday ? c.accent : Colors.transparent, width: 3),
              bottom: last
                  ? BorderSide.none
                  : (underline ? BorderSide(color: c.accent, width: 2) : BorderSide(color: c.line)),
            ),
          ),
          child: Row(
            children: [
              _dayCell(
                narrow,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${day.d}',
                            style: vt(narrow ? 12.5 : 14, 820, color: dayColor, height: 1.35),
                          ),
                          TextSpan(
                            text: ' ${weekdayShort[day.weekday]}',
                            style: vt(narrow ? 10.5 : 12.5, 660, color: isToday ? c.accent : c.muted, height: 1.35),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hijri != null)
                          Text('${hijri.d}', style: vt(narrow ? 9.5 : 11, 650, color: c.faint, height: 1.2)),
                        if (islamic) ...[const SizedBox(width: 3), _Dot(color: c.accent)],
                        if (holiday) ...[const SizedBox(width: 3), _Dot(color: dayColor)],
                      ],
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < 7; i++)
                Expanded(
                  flex: _timeFlex(narrow, i),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        fmtTime(times[i].local),
                        style: vt(
                          narrow ? 12.5 : 14,
                          isToday ? 860 : (narrow ? 700 : 680),
                          color: prayerColor(i, c.dark),
                          height: 1.5,
                        ),
                        softWrap: false,
                      ),
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

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 5,
    height: 5,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// The days of the month that the calendar marks, under the table.
class _MarkedDays extends StatelessWidget {
  const _MarkedDays({required this.marked, required this.controller});

  final List<(Day, List<DayNote>)> marked;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('DITËT E SHËNUARA', style: vt(12.5, 800, color: c.muted, ls: .08, height: 1.5)),
          const SizedBox(height: 6),
          for (final (day, notes) in marked)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      '${day.d} ${weekdayShort[day.weekday]}',
                      style: vt(
                        13.5,
                        800,
                        color: notes.any((n) => n.holiday) ? (c.dark ? _holidayDark : _holidayLight) : c.ink,
                        height: 1.4,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      [for (final n in notes) noteText(n, today: day == controller.today)].join(' · '),
                      style: vt(13.5, 600, color: c.ink, height: 1.4),
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
