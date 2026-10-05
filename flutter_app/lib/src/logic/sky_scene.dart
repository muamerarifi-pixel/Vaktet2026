/// What the sky shows besides its colours: the real Moon (its phase and where it is), and the little scenes that
/// belong to each hour of the day and the night.
///
/// The hours are *temporal hours*: the daylight between sunrise and sunset is split into 12 hours, and so is the
/// night. Hour 6 is always sunrise, 12 the middle of the day, 18 sunset and 0 the middle of the night, so every
/// scene keeps to the sun in every season and every year (a summer evening at 20:00 is still dusk, a winter one is
/// already night).
library;

import 'dart:math' as math;

import 'day.dart';
import 'prayer.dart';

// ---------- The Moon ----------

/// The Moon's phase at [utcMs], from its mean orbit with the main corrections (Meeus, *Astronomical Algorithms*,
/// ch. 48). Good to well under a day, which is far finer than the eye can tell.
({double illumination, bool waxing, double elongation}) moonPhase(int utcMs) {
  final jd = utcMs / msPerDay + 2440587.5;
  final t = (jd - 2451545.0) / 36525;
  double rad(double deg) => deg * math.pi / 180;
  final d = (297.8501921 + 445267.1114034 * t) % 360; // mean elongation of the Moon from the Sun
  final m = (357.5291092 + 35999.0502909 * t) % 360; // the Sun's mean anomaly
  final mp = (134.9633964 + 477198.8675055 * t) % 360; // the Moon's mean anomaly
  final i =
      180 -
      d -
      6.289 * math.sin(rad(mp)) +
      2.100 * math.sin(rad(m)) -
      1.274 * math.sin(rad(2 * d - mp)) -
      0.658 * math.sin(rad(2 * d)) -
      0.214 * math.sin(rad(2 * mp)) -
      0.110 * math.sin(rad(d));
  return (illumination: (1 + math.cos(rad(i))) / 2, waxing: d < 180, elongation: d);
}

/// The Moon as the sky draws it.
class MoonState {
  const MoonState({
    required this.up,
    required this.x,
    required this.y,
    required this.yFull,
    required this.illumination,
    required this.waxing,
  });

  /// Above the horizon.
  final bool up;
  final double x;

  /// Card sky.
  final double y;

  /// Full-screen sky.
  final double yFull;

  /// How much of the disc is lit, 0 (new moon) – 1 (full moon).
  final double illumination;

  /// Growing towards full (lit on the right, as seen from Kosovo).
  final bool waxing;

  @override
  bool operator ==(Object other) =>
      other is MoonState &&
      other.up == up &&
      other.x == x &&
      other.y == y &&
      other.yFull == yFull &&
      other.illumination == illumination &&
      other.waxing == waxing;

  @override
  int get hashCode => Object.hash(up, x, y, yFull, illumination, waxing);
}

/// Rounds to a step, so the sky is not repainted for changes nobody could see.
double _q(double v, [double step = 1 / 400]) => (v / step).roundToDouble() * step;

/// The Moon crosses the sky in about 12 hours and reaches its highest point one lunar day (24 h 50 min) per
/// orbit later than the Sun: at new moon it travels with the Sun, at full moon it rises as the Sun sets, at last
/// quarter it rises around midnight.
MoonState moonAt(List<PrayerRow> rows, int now) {
  final phase = moonPhase(now);
  final noon = rowOf(rows, PrayerKey.dhuhr).instant - 5 * msPerMinute; // the Sun at its highest
  const lunarDay = 24 * msPerHour + 50 * msPerMinute;
  const halfArc = 6.2 * msPerHour;
  // the Moon's highest point nearest to now
  final delay = phase.elongation / 360 * lunarDay;
  var transit = noon + delay;
  while (transit - now > lunarDay / 2) {
    transit -= lunarDay;
  }
  while (now - transit > lunarDay / 2) {
    transit += lunarDay;
  }
  final p = (now - (transit - halfArc)) / (2 * halfArc);
  final up = p > 0 && p < 1;
  final pc = p.clamp(0.0, 1.0);
  final s = math.sin(math.pi * pc);
  return MoonState(
    up: up,
    x: _q(0.12 + 0.76 * pc),
    y: _q(0.34 - 0.24 * s),
    yFull: _q(0.3 - 0.12 * s),
    illumination: _q(phase.illumination, 1 / 200),
    waxing: phase.waxing,
  );
}

// ---------- The hours ----------

/// The temporal hour at [now]: 6 = sunrise, 12 = mid-day, 18 = sunset, 0/24 = mid-night. Fractional.
double temporalHour(List<PrayerRow> rows, int now) {
  final rise = rowOf(rows, PrayerKey.sunrise).instant;
  final set = rowOf(rows, PrayerKey.maghrib).instant;
  if (now >= rise && now < set) return 6 + 12 * (now - rise) / (set - rise);
  // the night: from yesterday's sunset to today's sunrise, or from today's sunset to tomorrow's
  final from = now >= set ? set : set - msPerDay;
  final to = now >= set ? rise + msPerDay : rise;
  final h = 18 + 12 * (now - from) / (to - from);
  return h >= 24 ? h - 24 : h;
}

/// A soft bump: 0 outside [a, d], rising over a → b, 1 between b and c, falling over c → d.
/// Wraps around midnight when a > d.
double _window(double h, double a, double b, double c, double d) {
  double unwrap(double x) => x < a ? x + 24 : x;
  if (a > d) {
    h = unwrap(h);
    b = unwrap(b);
    c = unwrap(c);
    d = d + 24;
  }
  if (h <= a || h >= d) return 0;
  if (h < b) return _smooth((h - a) / (b - a));
  if (h <= c) return 1;
  return _smooth((d - h) / (d - c));
}

double _smooth(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// The colour each hour lays over the sky: (ARGB, strength). Index = temporal hour.
const List<(int, double)> hourTints = [
  (0xFF151A52, .16), // 0  the middle of the night: deepest blue
  (0xFF121848, .17),
  (0xFF141B4C, .15),
  (0xFF1D2358, .12),
  (0xFF3A2F6E, .10), // 4  the first grey of the Imsak
  (0xFF8A4F86, .10), // 5  violet before the dawn
  (0xFFFF9466, .12), // 6  sunrise: coral
  (0xFFFFC08A, .10), // 7  golden morning
  (0xFFFFE2B5, .06),
  (0xFFC8E6FF, .06), // 9  fresh blue
  (0xFFB5DCFF, .06),
  (0xFFE6F4FF, .06),
  (0xFFFFFFFF, .07), // 12 mid-day: white light
  (0xFFFFF4D6, .06),
  (0xFFFFE6B0, .07), // 14 warming
  (0xFFFFD48C, .09),
  (0xFFFFB86A, .11), // 16 golden hour
  (0xFFFF8E57, .13),
  (0xFFE55C78, .13), // 18 sunset: rose
  (0xFF8A4D9E, .13), // 19 the afterglow turns violet
  (0xFF4A3E8E, .13),
  (0xFF2E2F7A, .14), // 21 the evening blue
  (0xFF232769, .15),
  (0xFF1B205E, .16),
];

/// Everything the sky adds for the current hour, each 0–1, fading in and out smoothly.
class SkyScene {
  const SkyScene({
    required this.hour,
    required this.moon,
    required this.tint,
    required this.tintStrength,
    required this.milkyWay,
    required this.townLights,
    required this.brightStar,
    required this.mist,
    required this.birds,
    required this.plane,
    required this.nightPlane,
    required this.fireflies,
    required this.starBoost,
  });

  /// The temporal hour, 0–24.
  final double hour;
  final MoonState moon;

  /// The hour's colour over the sky (ARGB).
  final int tint;
  final double tintStrength;

  /// The band of the Milky Way, deep in the night.
  final double milkyWay;

  /// Share of the windows lit in the villages on the hills: on at dusk, going out one by one after midnight,
  /// a few back on for the Sabah prayer.
  final double townLights;

  /// The morning or evening star low over the hills.
  final double brightStar;

  /// Mist lying in the valleys after sunrise.
  final double mist;

  /// Birds flying out in the morning and home in the evening.
  final double birds;

  /// A plane drawing a thin trail across the day sky.
  final double plane;

  /// A plane's blinking lights crossing the evening sky.
  final double nightPlane;

  /// Fireflies over the meadows on summer evenings.
  final double fireflies;

  /// Extra stars and twinkle deep in the night (0 at dusk, 1 at mid-night).
  final double starBoost;

  @override
  bool operator ==(Object other) =>
      other is SkyScene &&
      other.hour == hour &&
      other.moon == moon &&
      other.tint == tint &&
      other.tintStrength == tintStrength;

  @override
  int get hashCode => Object.hash(hour, moon, tint, tintStrength);
}

int _lerpArgb(int a, int b, double t) {
  int ch(int shift) {
    final x = (a >> shift) & 0xFF, y = (b >> shift) & 0xFF;
    return (x + (y - x) * t).round() & 0xFF;
  }

  return (ch(24) << 24) | (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

SkyScene skySceneAt(List<PrayerRow> rows, int now, Day day) {
  // rounded so the scene only changes a few hundred times a day, not every second
  final h = _q(temporalHour(rows, now), 1 / 120);
  final i = h.floor() % 24, f = h - h.floor();
  final (ca, sa) = hourTints[i];
  final (cb, sb) = hourTints[(i + 1) % 24];
  final summer = day.m >= 6 && day.m <= 8;

  // the windows: all on in the evening, fewer and fewer after mid-night, some again before dawn
  double lights;
  if (h >= 18 && h < 24) {
    lights = _smooth((h - 18.4) / 1.2);
  } else if (h < 6.6) {
    final late = 1 - .8 * _smooth(h / 3.2); // going out until ~3
    final early = .45 * _window(h, 3.6, 4.6, 5.6, 6.6); // the Sabah prayer
    lights = math.max(late * (h < 5.5 ? 1 : _smooth((6.6 - h) / 1.1)), early);
  } else {
    lights = 0;
  }

  return SkyScene(
    hour: h,
    moon: moonAt(rows, now),
    tint: _lerpArgb(ca, cb, f),
    tintStrength: _q(sa + (sb - sa) * f, 1 / 400),
    milkyWay: _window(h, 20.2, 22.5, 3.2, 4.6),
    townLights: _q(lights, 1 / 40),
    brightStar: math.max(_window(h, 4.4, 5.0, 5.6, 6.1), _window(h, 18.1, 18.6, 19.2, 19.9)),
    mist: _window(h, 5.6, 6.3, 7.2, 8.6),
    birds: math.max(_window(h, 6.3, 6.8, 8.2, 9.0), _window(h, 16.4, 16.9, 17.6, 18.2)),
    plane: _window(h, 9.0, 9.6, 15.4, 16.0),
    nightPlane: _window(h, 19.0, 19.6, 23.0, 23.6),
    fireflies: summer ? _window(h, 18.6, 19.2, 21.6, 22.4) : 0,
    starBoost: _window(h, 19.5, 22.5, 2.5, 5.2),
  );
}
