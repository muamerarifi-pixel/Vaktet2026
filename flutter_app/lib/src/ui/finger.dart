import 'dart:math' as math;

/// Where a dragging finger is on each frame of the screen, so what follows it moves in even steps.
///
/// Android hands the touches over the moment they are sensed, 120 to 240 times a second (or more), out of step
/// with the screen's 60, 90 or 120 refreshes. Taking the newest touch on each frame, one frame sees two touches'
/// worth of movement and the next one three, and the sheet moves in uneven steps: it looks shaky however fast
/// the frames come.
///
/// Like Android's own views, this finds the finger at the same moment for every frame, between the two touches
/// around that moment. The moment is as far back as touches come in late on this phone (it learns that while the
/// finger moves, usually 5–15 ms), so there almost always is a touch on each side of it. If there is none yet,
/// it looks a few milliseconds ahead from the last two touches. If the touches' clock doesn't match the
/// screen's, or the finger rests, the newest touch is used as it is.
class FingerTrack {
  /// How many touches are kept.
  static const int _keep = 8;

  /// Touches closer together than this are too close to tell a speed from; further apart than [_maxGap], the
  /// finger rested between them.
  static const int _minGap = 2000, _maxGap = 20000;

  /// Never further ahead of the last touch than this (and never more than half the time between the last two).
  static const int _maxAhead = 8000;

  /// How far back the moment may be, in microseconds before the frame's time.
  static const int _minDelay = 4000, _maxDelay = 50000;

  /// Further apart than this, the touches and the frames don't share a clock.
  static const int _sameClock = 250000;

  /// (time in µs, position).
  final List<(int, double)> _touches = [];
  bool _fresh = false;

  /// How late the newest touch is, at most, lately: in µs before the frame's time.
  double _late = 0;
  bool _measured = false;

  /// The newest touch's position.
  double? get last => _touches.isEmpty ? null : _touches.last.$2;

  /// A new drag, starting with a touch at [position].
  void start(Duration? at, double position) {
    _touches.clear();
    _late = 0;
    _measured = false;
    add(at, position);
  }

  /// A touch at [position], sensed [at] (on the clock of the frames; null if not known).
  void add(Duration? at, double position) {
    final t = at?.inMicroseconds ?? (_touches.isEmpty ? 0 : _touches.last.$1);
    if (_touches.isNotEmpty && t <= _touches.last.$1) {
      // the same moment (or a clock that doesn't move): the newer position counts
      _touches[_touches.length - 1] = (_touches.last.$1, position);
    } else {
      _touches.add((t, position));
      if (_touches.length > _keep) _touches.removeAt(0);
    }
    _fresh = true;
  }

  /// Where to show the finger on the frame that will be on the screen at [frame].
  double? at(Duration frame) {
    if (_touches.isEmpty) return null;
    final now = frame.inMicroseconds;
    final (lastT, lastY) = _touches.last;
    final age = now - lastT;
    if (age.abs() > _sameClock || _touches.length < 2) {
      _fresh = false;
      return lastY;
    }
    if (_fresh) {
      // how late the touches come in: the highest lately, slowly let go of (a quarter of a millisecond a frame)
      _late = _measured ? math.max(age.toDouble(), _late - 250) : age.toDouble();
      _measured = true;
      _fresh = false;
    }
    final delay = math.max(_minDelay, math.min(_maxDelay, (_late + 1000).round()));
    final t = now - delay;
    if (t >= lastT) return _ahead(t);
    // between the two touches around that moment
    for (var i = _touches.length - 1; i > 0; i--) {
      final (aT, aY) = _touches[i - 1];
      if (aT <= t) {
        final (bT, bY) = _touches[i];
        return aY + (bY - aY) * (t - aT) / (bT - aT);
      }
    }
    return _touches.first.$2;
  }

  /// A little ahead of the last touch, along the last two.
  double _ahead(int t) {
    final (lastT, lastY) = _touches.last;
    final (prevT, prevY) = _touches[_touches.length - 2];
    final gap = lastT - prevT;
    if (gap < _minGap || gap > _maxGap) return lastY;
    final ahead = math.min(t - lastT, math.min(_maxAhead, gap ~/ 2));
    return lastY + (lastY - prevY) * ahead / gap;
  }
}
