import 'package:flutter/material.dart';

import '../logic/day.dart';
import '../logic/format.dart';
import '../logic/prayer.dart';
import '../logic/sky_scene.dart';
import '../logic/sun_moon.dart';
import 'colors.dart';
import 'svg_icon.dart';
import 'text.dart';
import 'widgets.dart';

/// More about the Sun or the Moon, opened by a tap on the note beside it in the sky.
Future<void> showSkyInfo(BuildContext context, {required bool sun, required TodayModel model, required int now}) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x73080E0C),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: _SkyInfo(sun: sun, model: model, now: now),
      ),
    ),
  );
}

String _duration(int ms) {
  final m = (ms / msPerMinute).round();
  if (m < 60) return '$m min';
  return '${m ~/ 60} orë ${m % 60} min';
}

Day _localDay(int ms) => Day.fromUtcMs(ms + kosovoOffsetAt(ms) * msPerMinute);

String _when(int ms, int now) {
  final d = _localDay(ms);
  final days = d.epochDay - _localDay(now).epochDay;
  final date = '${d.d} ${monthNames[d.m - 1]}';
  if (days <= 0) return 'sot, rreth ${fmtTime(((ms ~/ msPerMinute) + kosovoOffsetAt(ms)) % 1440)}';
  if (days == 1) return 'nesër, $date';
  return '${weekdayNames[d.weekday].toLowerCase()}, $date · pas $days ditësh';
}

class _SkyInfo extends StatelessWidget {
  const _SkyInfo({required this.sun, required this.model, required this.now});

  final bool sun;
  final TodayModel model;
  final int now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final String title;
    final String headline;
    final List<(String, String)> rows;
    final String note;
    if (sun) {
      final pos = sunPosition(now);
      final uv = uvIndex(now);
      final level = uvLevel(uv);
      final rise = rowOf(model.rows, PrayerKey.sunrise);
      final set = rowOf(model.rows, PrayerKey.maghrib);
      title = 'Dielli';
      headline = 'UV $uv — ${level.level}';
      rows = [
        ('Lartësia', '${pos.elevation.round()}° mbi horizont'),
        ('Drejtimi', '${compassName(pos.azimuth)} (${pos.azimuth.round()}°)'),
        ('Më i larti sot', '${sunHighest(now).round()}° në mesditë'),
        ('Lindja · perëndimi', '${fmtTime(rise.local)} · ${fmtTime(set.local)}'),
        ('Gjatësia e ditës', _duration(set.instant - rise.instant)),
        if (now < set.instant) ('Deri në perëndim', _duration(set.instant - now)),
      ];
      note = '${level.advice} Vlerësim për qiell të kthjellët: retë dhe mjegulla e ulin.';
    } else {
      final phase = moonPhase(now);
      title = 'Hëna';
      headline = moonPhaseName(phase.illumination, phase.waxing);
      rows = [
        ('Ndriçimi', '${(phase.illumination * 100).round()}% e diskut'),
        ('Mosha', '${moonAge(now).round()} ditë nga hëna e re'),
        ('Tani', phase.waxing ? 'po rritet drejt hënës së plotë' : 'po zvogëlohet drejt hënës së re'),
        ('Hëna e plotë', _when(nextMoon(now, full: true), now)),
        ('Hëna e re', _when(nextMoon(now, full: false), now)),
      ];
      note = 'Ditën hëna duket e zbehtë; natën shkëlqen dhe ndriçon qiellin.';
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        border: Border.all(color: colors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.dark ? .8 : .14),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -12,
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: vt(19, 850, color: colors.ink)),
                ),
                RoundIconButton(icon: VIcon.close, label: 'Mbyll', onTap: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 4),
            Text(headline, style: vt(16, 750, color: colors.accent, height: 1.3)),
            const SizedBox(height: 12),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(r.$1, style: vt(13.5, 600, color: colors.muted, height: 1.35)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 6,
                      child: Text(r.$2, style: vt(14, 700, color: colors.ink, height: 1.35)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.accentSoft,
                borderRadius: const BorderRadius.all(Radius.circular(14)),
              ),
              child: Text(note, style: vt(13, 600, color: colors.ink, height: 1.45)),
            ),
          ],
        ),
      ),
    );
  }
}
