// Following a dragging finger in even steps, however the touches fall between the frames of the screen.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vaktet/src/ui/finger.dart';

/// A finger moving at 1 pixel a millisecond, sensed [touchHz] times a second (the times rounded to whole
/// milliseconds, as Android gives them), each touch reaching the app [lateMs] (± [jitterMs]) later; frames at
/// [screenHz], each one looked at 1 ms after its refresh began (its time is when it will be shown, a refresh later).
///
/// Returns the steps the sheet makes from frame to frame, following the newest touch as it is (`raw`) and through
/// [FingerTrack] (`track`), and how far behind the finger each one shows it, on average (in pixels, = ms).
({List<double> raw, List<double> track, double rawLag, double trackLag}) _drag({
  required double touchHz,
  required double screenHz,
  double lateMs = 6,
  double jitterMs = 2,
}) {
  final rnd = math.Random(7);
  final touchEvery = 1e6 / touchHz, frameEvery = 1e6 / screenHz;
  const t0 = 5e6;
  final touches = <(int, double, double)>[]; // (time stamp µs, position, arrives µs)
  for (var t = t0; t < t0 + 1.2e6; t += touchEvery) {
    touches.add((t ~/ 1000 * 1000, t / 1000, t + (lateMs + (rnd.nextDouble() * 2 - 1) * jitterMs) * 1000));
  }
  final track = FingerTrack();
  var given = 0;
  final raw = <double>[], tracked = <double>[];
  var rawLag = 0.0, trackLag = 0.0;
  var frames = 0;
  for (var refresh = t0 + 50000; refresh < t0 + 1.1e6; refresh += frameEvery) {
    final lookAt = refresh + 1000;
    while (given < touches.length && touches[given].$3 <= lookAt) {
      final (stamp, y, _) = touches[given];
      if (given == 0) {
        track.start(Duration(microseconds: stamp), y);
      } else {
        track.add(Duration(microseconds: stamp), y);
      }
      given++;
    }
    if (given == 0) continue;
    final shown = track.at(Duration(microseconds: (refresh + frameEvery).round()))!;
    final newest = touches[given - 1].$2;
    if (frames++ >= 20) {
      raw.add(newest);
      tracked.add(shown);
      rawLag += refresh / 1000 - newest;
      trackLag += refresh / 1000 - shown;
    }
  }
  List<double> steps(List<double> at) => [for (var i = 1; i < at.length; i++) at[i] - at[i - 1]];
  final n = raw.length;
  return (raw: steps(raw), track: steps(tracked), rawLag: rawLag / n, trackLag: trackLag / n);
}

/// How uneven the steps are: their standard deviation.
double _uneven(List<double> steps) {
  final mean = steps.reduce((a, b) => a + b) / steps.length;
  return math.sqrt(steps.map((s) => (s - mean) * (s - mean)).reduce((a, b) => a + b) / steps.length);
}

void main() {
  test('on every kind of phone, the sheet moves in even steps, barely later than the newest touch', () {
    for (final (touchHz, screenHz) in const [
      (240.0, 120.0),
      (240.0, 90.0),
      (240.0, 60.0),
      (120.0, 90.0),
      (360.0, 120.0),
      (180.0, 90.0),
      (60.0, 120.0),
    ]) {
      final d = _drag(touchHz: touchHz, screenHz: screenHz);
      final step = 1000 / screenHz;
      final why = '$touchHz Hz touches, $screenHz Hz screen';
      // the newest touch alone jumps by whole touches; followed through the track, the steps are nearly the same
      expect(_uneven(d.track), lessThan(step * .1), reason: why);
      expect(_uneven(d.track), lessThan(_uneven(d.raw) / 2), reason: why);
      // and the sheet is only a few milliseconds further behind the finger
      expect(d.trackLag - d.rawLag, lessThan(6), reason: why);
    }
  });

  test('a finger that stops: the sheet stops exactly where it is', () {
    final track = FingerTrack()..start(const Duration(milliseconds: 1000), 0);
    for (var ms = 1004; ms <= 1100; ms += 4) {
      track.add(Duration(milliseconds: ms), (ms - 1000).toDouble());
    }
    // long after the last touch, nothing is guessed any more
    expect(track.at(const Duration(milliseconds: 1600)), 100);
    expect(track.last, 100);
  });

  test('looking ahead is short: never more than half the time between the last two touches', () {
    final track = FingerTrack()
      ..start(const Duration(milliseconds: 1000), 0)
      ..add(const Duration(milliseconds: 1008), 8);
    // the touches come in early on this phone, so it looks back only a little: between the two touches
    expect(track.at(const Duration(milliseconds: 1012)), closeTo(7, .01));
    // a frame with no new touch for its moment: a little ahead of the last one, along the last two
    final y = track.at(const Duration(milliseconds: 1020))!;
    expect(y, greaterThan(8));
    expect(y, lessThanOrEqualTo(12));
    // and much later, it stays there
    expect(track.at(const Duration(milliseconds: 1060)), lessThanOrEqualTo(12));
  });

  test('touches without a time, or on another clock than the frames: the newest touch, as it is', () {
    // tests and accessibility give no time (zero): every touch is the same moment
    final none = FingerTrack()..start(Duration.zero, 500);
    none
      ..add(Duration.zero, 480)
      ..add(Duration.zero, 460);
    expect(none.at(const Duration(seconds: 1000)), 460);
    expect(none.at(const Duration(milliseconds: 30)), 460);
    expect(none.at(Duration.zero), 460);
    final other = FingerTrack()..start(const Duration(milliseconds: 10), 0);
    for (var ms = 14; ms < 60; ms += 4) {
      other.add(Duration(milliseconds: ms), ms.toDouble());
    }
    expect(other.at(const Duration(hours: 5)), other.last);
  });

  test('nothing to show before the first touch', () {
    expect(FingerTrack().at(const Duration(seconds: 1)), isNull);
    expect(FingerTrack().last, isNull);
  });
}
