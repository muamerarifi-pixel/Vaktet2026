/// Daily tips. Two per day, never the same day to day: even days get one life tip and one tip
/// as a Muslim, odd days two life tips. Each list is gone through in a shuffled order before
/// any tip comes back. (A port of the web app's logic; the shuffle uses 32-bit integer maths
/// so it picks exactly the same tips.)
library;

import '../data/tips_data.dart';
import 'day.dart';

class Tip {
  const Tip(this.tag, this.text, {this.muslim = false});

  final String tag;
  final String text;
  final bool muslim;
}

const int _mask = 0xFFFFFFFF;

/// 32-bit multiply, like JavaScript's `Math.imul`, returned as an unsigned value.
int _imul(int a, int b) {
  final ah = (a >> 16) & 0xFFFF, al = a & 0xFFFF;
  final bh = (b >> 16) & 0xFFFF, bl = b & 0xFFFF;
  return ((al * bl) + (((ah * bl + al * bh) << 16) & _mask)) & _mask;
}

/// A shuffled `0 … n-1`, seeded.
List<int> shuffled(int n, int seed) {
  var a = seed & _mask;
  double rnd() {
    a = (a + 0x6D2B79F5) & _mask;
    var t = a;
    t = _imul(t ^ (t >> 15), t | 1);
    t = (t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & _mask)) & _mask;
    return ((t ^ (t >> 14)) & _mask) / 4294967296.0;
  }

  final idx = List<int>.generate(n, (i) => i);
  for (var i = n - 1; i > 0; i--) {
    final j = (rnd() * (i + 1)).floor();
    final t = idx[i];
    idx[i] = idx[j];
    idx[j] = t;
  }
  return idx;
}

int _floorDiv(int a, int b) => (a / b).floor();

String _tipAt(List<String> list, int k, int salt) {
  final n = list.length;
  final cycle = _floorDiv(k, n);
  return list[shuffled(n, cycle * 7919 + salt + 1000000)[((k % n) + n) % n]];
}

/// 1 Oct 2026 is day 0.
const int _tipsEpochDay = 20727;

List<Tip> tipsFor(Day day) {
  final d = day.epochDay - _tipsEpochDay;
  final pair = _floorDiv(d, 2);
  if (((d % 2) + 2) % 2 == 0) {
    return [
      Tip('Për jetën', _tipAt(tipsLife, pair * 3, 11)),
      Tip('Si musliman', _tipAt(tipsMuslim, pair, 29), muslim: true),
    ];
  }
  return [Tip('Për jetën', _tipAt(tipsLife, pair * 3 + 1, 11)), Tip('Për jetën', _tipAt(tipsLife, pair * 3 + 2, 11))];
}
