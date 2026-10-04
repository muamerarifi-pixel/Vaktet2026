// Checks the Dart port against what the original web app displays.
//
// The fixture (test/fixtures/web_reference.json) was recorded by tool/gen_web_reference.mjs: it loads the
// web app in Chromium, fakes the clock to many instants (edges of every prayer time, summer-time switch
// days, Fridays, 29 Feb, forbidden times) and stores the visible text. Set WEB_REFERENCE to use a bigger file.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaktet/src/logic/cities.dart';
import 'package:vaktet/src/logic/day.dart';
import 'package:vaktet/src/logic/format.dart';
import 'package:vaktet/src/logic/prayer.dart';
import 'package:vaktet/src/logic/tips.dart';

const _nbsp = ' ';

void main() {
  final path = Platform.environment['WEB_REFERENCE'] ?? 'test/fixtures/web_reference.json';
  final ref = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  final snaps = (ref['snapshots'] as List).cast<Map<String, dynamic>>();

  test('fixture is present', () => expect(snaps.length, greaterThan(100)));

  test('today screen matches the web app at ${snaps.length} instants', () {
    final problems = <String>[];
    void check(String what, Object? got, Object? want, Map<String, dynamic> s) {
      if (got != want) {
        final at = DateTime.fromMillisecondsSinceEpoch(s['t'] as int, isUtc: true).toIso8601String();
        problems.add('$at ${s['c']} $what: dart=$got web=$want');
      }
    }

    for (final s in snaps) {
      final now = s['t'] as int;
      final city = cityById(s['c'] as String);
      final today = kosovoToday(now);
      final m = computeToday(now: now, today: today, selected: today, city: city, alarmOffset: s['al'] as int);
      final card = m.card!;

      check('date', longDate(today), s['date'], s);
      final hijri = hijriText(today, s['adj'] as int);
      check('hijri', hijri.isEmpty ? _nbsp : hijri, s['hijri'], s);
      check('intro', card.intro, s['intro'], s);
      check('name', card.name, s['name'], s);
      check('time', card.time, s['time'], s);
      check('countdown', fmtCount(card.target - now), s['cd'], s);
      check('countdown label', card.countdownLabel, s['cdl'], s);
      check('forbidden', card.forbidden, s['forbid'], s);
      final alt = s['alt'] as List?;
      check(
        'alt',
        card.altText == null ? null : [card.altText, fmtCount(card.altTarget! - now)].join('|'),
        alt?.join('|'),
        s,
      );
      final alarm = s['alarm'] as List?;
      check('alarm', m.alarm == null ? null : '${m.alarm!.time}|${m.alarm!.sub}', alarm?.join('|'), s);

      final rows = (s['rows'] as List).cast<List>();
      check('row count', m.rows.length, rows.length, s);
      for (var i = 0; i < rows.length && i < m.rows.length; i++) {
        final r = m.rows[i];
        final mark = identical(r, m.nextRow) ? 'n' : (m.isPast(r, now) ? 'p' : '');
        check('row $i', '${r.name}|${fmtTime(r.local)}|$mark', rows[i].join('|'), s);
      }
      check('note', cityNote(city), s['note'], s);
      check('phase', m.phase.name, s['phase'], s);
      check('orb', m.orb.sun ? 'sun' : 'moon', s['orb'], s);
      for (final e in {'ox': m.orb.x, 'oy': m.orb.y, 'oyf': m.orb.yFocus, 'oyz': m.orb.yFull}.entries) {
        check(e.key, e.value.toStringAsFixed(4), s[e.key], s);
      }
      // The browser normalises "50.00%" to "50%", so compare the numbers.
      double pct(String v) => double.parse(v.replaceAll('%', ''));
      final ticks = (s['ticks'] as List).cast<List>();
      for (var i = 0; i < ticks.length; i++) {
        final r = m.rows[i];
        check(
          'tick $i',
          '${(r.local / 1440 * 100).toStringAsFixed(2)}|${r.instant <= now}',
          '${pct(ticks[i][0] as String).toStringAsFixed(2)}|${ticks[i][1]}',
          s,
        );
      }
      check('dayline fill', (m.dayFraction * 100).toStringAsFixed(2), pct(s['fill'] as String).toStringAsFixed(2), s);
    }
    if (problems.isNotEmpty) {
      fail('${problems.length} differences, first ones:\n${problems.take(25).join('\n')}');
    }
  });

  test('daily tips match the web app', () {
    final tips = (ref['tips'] as Map<String, dynamic>);
    final byDate = <String, Day>{};
    for (final s in snaps) {
      byDate[s['date'] as String] = kosovoToday(s['t'] as int);
    }
    expect(tips, isNotEmpty);
    tips.forEach((date, want) {
      final got = tipsFor(byDate[date]!).map((t) => '${t.tag}|${t.text}').toList();
      expect(got, (want as List).map((e) => (e as List).join('|')).toList(), reason: date);
    });
  });

  test('month tables match the web app (all cities)', () {
    final months = (ref['months'] as Map<String, dynamic>);
    months.forEach((key, rows) {
      final parts = key.split(':');
      final city = cityById(parts[0]);
      final ym = parts[1].split('-').map(int.parse).toList();
      final list = rows as List;
      for (var d = 1; d <= list.length; d++) {
        final got = dayTimes(Day(ym[0], ym[1], d), city).map((t) => fmtTime(t.local)).toList();
        expect(got, (list[d - 1] as List).cast<String>(), reason: '$key day $d');
      }
    });
  });
}
