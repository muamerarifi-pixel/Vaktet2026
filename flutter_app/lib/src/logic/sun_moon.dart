/// The Sun's place in the sky and its UV, and the Moon's phase in words: the small notes beside them on the sky.
///
/// Everything is worked out on the phone (the app works offline), for the middle of Kosovo: the cities differ by
/// far less than the eye or the UV scale can tell.
library;

import 'dart:math' as math;

import 'day.dart';
import 'sky_scene.dart';

const double _lat = 42.6;
const double _lon = 20.9;

/// Days from one new moon to the next.
const double synodicMonth = 29.530589;

double _rad(double d) => d * math.pi / 180;
double _deg(double r) => r * 180 / math.pi;

/// Where the Sun is at [utcMs], seen from Kosovo: its height above the horizon and its compass direction
/// (degrees from north, clockwise), both in degrees, and its declination.
({double elevation, double azimuth, double declination}) sunPosition(int utcMs) {
  final n = utcMs / msPerDay + 2440587.5 - 2451545.0;
  final l = (280.460 + 0.9856474 * n) % 360;
  final g = _rad((357.528 + 0.9856003 * n) % 360);
  final lambda = _rad(l + 1.915 * math.sin(g) + 0.020 * math.sin(2 * g));
  final eps = _rad(23.439 - 0.0000004 * n);
  final ra = math.atan2(math.cos(eps) * math.sin(lambda), math.cos(lambda));
  final dec = math.asin(math.sin(eps) * math.sin(lambda));
  final gmst = (280.46061837 + 360.98564736629 * n) % 360;
  final ha = _rad(gmst + _lon) - ra;
  final lat = _rad(_lat);
  final el = math.asin(math.sin(lat) * math.sin(dec) + math.cos(lat) * math.cos(dec) * math.cos(ha));
  final az = math.atan2(-math.sin(ha), math.tan(dec) * math.cos(lat) - math.sin(lat) * math.cos(ha));
  return (elevation: _deg(el), azimuth: (_deg(az) + 360) % 360, declination: _deg(dec));
}

/// The Sun's highest point on the day of [utcMs], in degrees above the horizon.
double sunHighest(int utcMs) => 90 - _lat + sunPosition(utcMs).declination;

/// The UV index under a clear sky (the WHO scale): from the Sun's height, the ozone of the season, the distance to
/// the Sun and the height of Kosovo above the sea. Clouds and haze bring it down.
int uvIndex(int utcMs) {
  final el = sunPosition(utcMs).elevation;
  if (el <= 0) return 0;
  final t = DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true);
  final doy = t.difference(DateTime.utc(t.year)).inDays + 1;
  final ozone = 325 + 35 * math.cos(2 * math.pi * (doy - 95) / 365);
  final distance = 1 + 0.034 * math.cos(2 * math.pi * (doy - 3) / 365);
  final mu = math.sin(_rad(el));
  final uv = 0.9 * 12.5 * math.pow(mu, 2.42) * math.pow(ozone / 300, -1.23) * distance * 1.036;
  return uv.round();
}

/// The UV index in words, and what to do about it.
({String level, String advice}) uvLevel(int uv) {
  if (uv <= 2) return (level: 'i ulët', advice: 'Nuk nevojitet mbrojtje e veçantë.');
  if (uv <= 5) return (level: 'mesatar', advice: 'Rreth mesditës: kapelë, syze dielli dhe krem mbrojtës.');
  if (uv <= 7) return (level: 'i lartë', advice: 'Krem SPF 30+ dhe kapelë; rreth mesditës kërkoni hije.');
  if (uv <= 10) return (level: 'shumë i lartë', advice: 'Shmangni diellin rreth mesditës; krem SPF 50+.');
  return (level: 'ekstrem', advice: 'Qëndroni në hije: dielli djeg brenda pak minutash.');
}

/// A compass direction in Albanian.
String compassName(double azimuth) => const [
  'veri',
  'verilindje',
  'lindje',
  'juglindje',
  'jug',
  'jugperëndim',
  'perëndim',
  'veriperëndim',
][((azimuth + 22.5) % 360 ~/ 45) % 8];

/// The Moon's phase in words.
String moonPhaseName(double illumination, bool waxing) {
  if (illumination < .02) return 'Hëna e re';
  if (illumination > .98) return 'Hëna e plotë';
  if ((illumination - .5).abs() < .06) return waxing ? 'Çereku i parë' : 'Çereku i fundit';
  if (illumination < .5) return waxing ? 'Hilal në rritje' : 'Hilal në zbritje';
  return waxing ? 'Hëna po mbushet' : 'Hëna po zvogëlohet';
}

/// The Moon's age: days since the last new moon.
double moonAge(int utcMs) => moonPhase(utcMs).elongation / 360 * synodicMonth;

/// The moment of the next full moon (or new moon) after [utcMs], to within an hour or two.
int nextMoon(int utcMs, {required bool full}) {
  final target = full ? 180.0 : 0.0;
  final days = ((target - moonPhase(utcMs).elongation) % 360) / 360 * synodicMonth;
  var t = _refine(utcMs + (days * msPerDay).round(), full);
  if (t < utcMs - 12 * msPerHour) t = _refine(t + (synodicMonth * msPerDay).round(), full);
  return t;
}

/// The hour within a day and a quarter of [guess] when the lit part is largest (or smallest).
int _refine(int guess, bool full) {
  var best = guess;
  var bestValue = full ? -1.0 : 2.0;
  for (var h = -30; h <= 30; h++) {
    final t = guess + h * msPerHour;
    final v = moonPhase(t).illumination;
    if (full ? v > bestValue : v < bestValue) {
      bestValue = v;
      best = t;
    }
  }
  return best;
}
