import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../logic/prayer.dart';
import '../logic/sun_moon.dart';
import 'colors.dart';
import 'landscape.dart';
import 'sky_info.dart';
import 'text.dart';

/// How the sky card is shown.
enum SkyMode {
  /// A rounded card at the top of the page.
  card,

  /// The sky fills the whole screen.
  full,
}

/// The clock of everything that moves on the sky: the drifting clouds, the twinkling stars, the birds and planes.
///
/// It ticks with the screen itself, on every refresh (60, 90 or 120 times a second, whatever the phone shows), so
/// the sky moves as smoothly as the screen can show it. There is one clock for the whole app.
///
/// It runs while someone holds it (the sky on the screen), and its time stands still in between (the app out of
/// sight), so nothing jumps when it starts again.
class SkyClock extends ChangeNotifier {
  SkyClock._();

  static final SkyClock shared = SkyClock._();

  final Set<Object> _holders = {};
  late final Ticker _ticker = Ticker(_tick, debugLabel: 'SkyClock');

  /// The time it ran before the current run, and in the current run.
  Duration _before = Duration.zero;
  Duration _run = Duration.zero;

  /// The clock's own time: it only moves while the clock runs.
  double get seconds => (_before + _run).inMicroseconds / 1e6;

  bool get running => _ticker.isActive;

  bool isHeldBy(Object who) => _holders.contains(who);

  /// Keeps the clock running until [who] lets go.
  void hold(Object who) {
    if (!_holders.add(who) || _ticker.isActive) return;
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    _run = elapsed;
    notifyListeners();
  }

  void release(Object who) {
    if (!_holders.remove(who) || _holders.isNotEmpty) return;
    _ticker.stop();
    _before += _run;
    _run = Duration.zero;
  }
}

/// Still layers of the sky, painted once into a picture at the screen's own resolution, and that picture shown on
/// every frame.
///
/// The screen is drawn again on every refresh (the stars twinkle, the clouds drift), and showing one picture is a
/// single quick step where the gradients, the thousand faint stars, the Milky Way, the mountains, the lake and the
/// mist would be hundreds. They are painted again only when the light changes (about once a minute), or the
/// screen changes size.
class StillSky extends LeafRenderObjectWidget {
  const StillSky({super.key, required this.painters});

  /// Painted one over the other, in this order.
  final List<CustomPainter> painters;

  @override
  RenderStillSky createRenderObject(BuildContext context) =>
      RenderStillSky(painters, MediaQuery.devicePixelRatioOf(context));

  @override
  void updateRenderObject(BuildContext context, RenderStillSky renderObject) => renderObject
    ..painters = painters
    ..pixelRatio = MediaQuery.devicePixelRatioOf(context);
}

class RenderStillSky extends RenderBox {
  RenderStillSky(this._painters, this._pixelRatio);

  List<CustomPainter> _painters;
  set painters(List<CustomPainter> value) {
    var changed = value.length != _painters.length;
    for (var i = 0; !changed && i < value.length; i++) {
      final now = value[i], was = _painters[i];
      changed = now.runtimeType != was.runtimeType || now.shouldRepaint(was);
    }
    _painters = value;
    if (changed) _forget();
  }

  double _pixelRatio;
  set pixelRatio(double value) {
    if (value == _pixelRatio) return;
    _pixelRatio = value;
    _forget();
  }

  ui.Image? _image;
  Size? _imageFor;

  /// Whether the picture is there (for tests).
  bool get hasPicture => _image != null;

  void _forget() {
    _image?.dispose();
    _image = null;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  /// Its picture changes on its own, and nothing around it paints it again.
  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) return;
    if (_image == null || _imageFor != size) {
      _image?.dispose();
      _image = _render();
      _imageFor = size;
    }
    final image = _image!;
    context.canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      offset & size,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  ui.Image _render() {
    // the screen's own pixels, but never a huge picture (a tablet): at most about 9 million pixels, 4096 a side
    final area = size.width * size.height;
    final scale = math.max(
      .25,
      math.min(_pixelRatio, math.min(4096 / math.max(size.width, size.height), math.sqrt(9.4e6 / area))),
    );
    final w = math.max(1, (size.width * scale).ceil()), h = math.max(1, (size.height * scale).ceil());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(w / size.width, h / size.height);
    for (final painter in _painters) {
      painter.paint(canvas, size);
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(w, h);
    picture.dispose();
    return image;
  }

  @override
  void dispose() {
    _image?.dispose();
    _image = null;
    super.dispose();
  }
}

// brightness(.86) saturate(.95): the same skies, a little dimmer at night so they don't glare.
const double _dimS = 0.95, _dimB = 0.86;
const List<double> _dimMatrix = [
  (0.213 + 0.787 * _dimS) * _dimB,
  (0.715 - 0.715 * _dimS) * _dimB,
  (0.072 - 0.072 * _dimS) * _dimB,
  (0.213 - 0.213 * _dimS) * _dimB,
  (0.715 + 0.285 * _dimS) * _dimB,
  (0.072 - 0.072 * _dimS) * _dimB,
  (0.213 - 0.213 * _dimS) * _dimB,
  (0.715 - 0.715 * _dimS) * _dimB,
  (0.072 + 0.928 * _dimS) * _dimB,
];

final ColorFilter _darkFilter = ColorFilter.matrix([
  _dimMatrix[0], _dimMatrix[1], _dimMatrix[2], 0, 0, //
  _dimMatrix[3], _dimMatrix[4], _dimMatrix[5], 0, 0,
  _dimMatrix[6], _dimMatrix[7], _dimMatrix[8], 0, 0,
  0, 0, 0, 1, 0,
]);

/// The dark-theme filter applied to one colour. The filter is linear, so filtering each colour gives the same
/// picture as filtering the whole layer, without the cost of an offscreen layer on every frame.
Color _dim(Color c) {
  final m = _dimMatrix;
  double ch(int i) => (m[i] * c.r + m[i + 1] * c.g + m[i + 2] * c.b).clamp(0.0, 1.0);
  return Color.from(alpha: c.a, red: ch(0), green: ch(3), blue: ch(6));
}

/// The stars of the card: (x %, y %, size).
const List<(double, double, double)> _stars = [
  (8, 14, 1.3),
  (17, 46, 1),
  (27, 22, 1.6),
  (36, 8, 1),
  (44, 38, 1.2),
  (53, 16, 1),
  (61, 30, 1.5),
  (70, 9, 1),
  (79, 42, 1.3),
  (87, 20, 1),
  (94, 34, 1.6),
  (4, 58, 1),
  (31, 62, 1.1),
  (66, 56, 1),
  (91, 64, 1.2),
];

/// A star of the full-screen sky: where it is (0–1), how big, how bright, its tint, and how it twinkles.
class _Star {
  const _Star(this.x, this.y, this.r, this.bright, this.tint, this.period, this.phase, this.depth);

  final double x;
  final double y;

  /// Radius in logical pixels.
  final double r;

  /// Brightness, 0–1.
  final double bright;
  final Color tint;
  final double period;
  final double phase;

  /// How far the star dims at the bottom of its twinkle.
  final double depth;

  /// Only the brighter stars twinkle where the eye can see it; the faint ones are drawn once and kept.
  bool get twinkles => r > .7 || bright > .55;
}

/// The same stars on every start (a fixed seed): mostly tiny and faint, a handful a little brighter,
/// some faintly blue or warm, each twinkling on its own beat. The first [_baseStars] are always there, the next
/// [_deepStars] come out deep in the night, and the last [_fridayStars] only on the night before Friday.
const int _baseStars = 170;
const int _deepStars = 90;
const int _fridayStars = 340;

final List<_Star> _fieldStars = () {
  final rnd = math.Random(1447);
  const tints = [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFDCE6FF), Color(0xFFFFF1DE)];
  return List<_Star>.generate(_baseStars + _deepStars + _fridayStars, (i) {
    final y = math.pow(rnd.nextDouble(), 1.15).toDouble(); // a little denser towards the top
    final lucky = i < _baseStars && rnd.nextDouble() < .07;
    final bright = lucky ? .8 + rnd.nextDouble() * .2 : .22 + math.pow(rnd.nextDouble(), 2) * .5;
    return _Star(
      rnd.nextDouble(),
      y,
      lucky ? .8 + rnd.nextDouble() * .35 : .35 + rnd.nextDouble() * .4,
      bright,
      tints[rnd.nextInt(tints.length)],
      1.4 + rnd.nextDouble() * 3.6,
      rnd.nextDouble() * 2 * math.pi,
      .4 + rnd.nextDouble() * .5,
    );
  });
}();

/// Stars too faint to twinkle, all over the sky down to the mountains: (x, y, radius, brightness), y from the top
/// (0) to the mountains (1). The first [_baseDust] are always there; the rest come out only deep in the night.
const int _baseDust = 460;

final List<(double, double, double, double)> _dust = () {
  final rnd = math.Random(2718);
  return List.generate(
    _baseDust + 200,
    (_) => (
      rnd.nextDouble(),
      math.pow(rnd.nextDouble(), 1.1).toDouble(),
      .28 + rnd.nextDouble() * .32,
      .22 + math.pow(rnd.nextDouble(), 2).toDouble() * .68,
    ),
  );
}();

/// The glowing clouds of the Milky Way: (along the band 0–1, across it −1…1, size, brightness).
final List<(double, double, double, double)> _milkyClouds = () {
  final rnd = math.Random(4242);
  return List.generate(16, (i) {
    final along = (i + .5) / 16 + (rnd.nextDouble() - .5) * .05;
    return (along, (rnd.nextDouble() - .5) * .7, .45 + rnd.nextDouble() * .7, .45 + rnd.nextDouble() * .55);
  });
}();

/// The faint dust of the Milky Way: (along the band 0–1, across it −1…1, size, brightness).
final List<(double, double, double, double)> _milkyDust = () {
  final rnd = math.Random(786);
  return List.generate(260, (_) {
    // bunched towards the middle of the band
    final across = (rnd.nextDouble() + rnd.nextDouble() + rnd.nextDouble() - 1.5) / 1.5;
    return (rnd.nextDouble(), across, .25 + rnd.nextDouble() * .35, .25 + rnd.nextDouble() * .55);
  });
}();

/// Windows in the villages on the hills, in the hills' own 400 × 60 space: (x, y, warmth, order they go out).
final List<(double, double, double, double)> _windows = () {
  final rnd = math.Random(1912);
  final near = _nearHill(), far = _farHill();
  final out = <(double, double, double, double)>[];
  // a few villages, each a small cluster of windows
  for (final (vx, count) in const [(70.0, 8), (150.0, 7), (232.0, 10), (290.0, 9), (356.0, 7)]) {
    var tries = 0;
    var made = 0;
    while (made < count && tries < 200) {
      tries++;
      final x = vx + (rnd.nextDouble() - .5) * 40;
      // high on the slopes, where they show above the tabs
      final y = 14 + rnd.nextDouble() * 28;
      final p = Offset(x, y);
      // on the slopes, not floating in the air, and not too deep in the dark foot of the hills
      final onNear = near.contains(p) && !near.contains(p.translate(0, -5));
      final onFar = !near.contains(p) && far.contains(p) && !far.contains(p.translate(0, -6));
      if (!onNear && !onFar) continue;
      out.add((x, y, rnd.nextDouble(), rnd.nextDouble()));
      made++;
    }
  }
  return out;
}();

/// Fireflies: (home x, home y, wander speed, phase).
final List<(double, double, double, double)> _fireflies = () {
  final rnd = math.Random(613);
  return List.generate(
    16,
    (_) => (rnd.nextDouble(), .74 + rnd.nextDouble() * .2, .5 + rnd.nextDouble(), rnd.nextDouble() * 2 * math.pi),
  );
}();

Path _farHill() => Path()
  ..moveTo(0, 34)
  ..cubicTo(30, 27, 58, 30, 92, 22)
  ..relativeCubicTo(30, -7, 52, 2, 84, 6)
  ..relativeCubicTo(34, 4, 58, -17, 96, -19)
  ..relativeCubicTo(30, -2, 48, 12, 76, 13)
  ..relativeCubicTo(22, 1, 36, -6, 52, -8)
  ..lineTo(400, 60)
  ..lineTo(0, 60)
  ..close();

Path _nearHill() => Path()
  ..moveTo(0, 46)
  ..relativeCubicTo(36, -7, 66, -2, 104, -9)
  ..relativeCubicTo(40, -7, 70, 6, 112, 5)
  ..relativeCubicTo(40, -1, 64, -12, 102, -12)
  ..relativeCubicTo(34, 0, 58, 8, 82, 6)
  ..lineTo(400, 60)
  ..lineTo(0, 60)
  ..close();

final Path _farHillPath = _farHill();
final Path _nearHillPath = _nearHill();

/// Soft clouds of the full-screen day sky: (height 0–1, size, seconds to cross the screen, start offset).
/// The first ones come out first; the afternoon brings them all.
const List<(double, double, double, double)> _clouds = [
  (.14, 1.0, 150, .10),
  (.30, .75, 115, .62),
  (.44, .55, 95, .35),
  (.22, .85, 170, .85),
  (.38, .65, 130, .22),
];

/// The puffs of one cloud, relative to its centre and size: (dx, dy, radius).
const List<(double, double, double)> _puffs = [
  (-.55, .10, .34),
  (-.22, -.08, .46),
  (.16, -.16, .52),
  (.50, .02, .40),
  (.02, .14, .44),
];

/// The day's clouds, each painted once into an image of its own, so that a frame only moves a few images across
/// the sky instead of painting dozens of soft circles. They are painted again only when the hour changes their
/// look (about once a minute) or the screen changes size.
class _CloudImages {
  static Object? _key;
  static List<ui.Image> _images = const [];

  static List<ui.Image> of(double w, SkyScene scene, Color Function(Color)? dim) {
    final key = (w, scene.cloudCover, scene.cloudThin, scene.cloudSunset, dim != null);
    if (key == _key) return _images;
    for (final image in _images) {
      image.dispose();
    }
    _key = key;
    return _images = _paint(w, scene, dim ?? (c) => c);
  }

  static List<ui.Image> _paint(double w, SkyScene scene, Color Function(Color) k) {
    final cover = scene.cloudCover, thin = scene.cloudThin, sunset = scene.cloudSunset;
    final strength = .3 * (.55 + .45 * cover);
    const white = Color(0xFFFFFFFF);
    final tint = Color.lerp(white, const Color(0xFFFFB09A), sunset)!;
    final rim = Color.lerp(white, const Color(0xFFFFD08A), sunset)!;
    final shown = cover * _clouds.length;
    final paint = Paint();
    final images = <ui.Image>[];
    for (var i = 0; i < _clouds.length; i++) {
      final fade = (shown - i).clamp(0.0, 1.0);
      if (fade <= 0) break;
      final (_, scale0, _, _) = _clouds[i];
      final cw = w * .55 * scale0 * (.75 + .45 * cover);
      final iw = (cw * 2.4 * (1 + .3 * thin)).ceil(), ih = (cw * 1.5).ceil();
      final centre = Offset(iw / 2, ih / 2);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      // thin morning clouds are flattened into wisps
      canvas.translate(centre.dx, centre.dy);
      canvas.scale(1 + .3 * thin, 1 - .55 * thin);
      canvas.translate(-centre.dx, -centre.dy);
      final a = strength * (.75 + .25 * scale0) * fade;
      for (final (dx, dy, r) in _puffs) {
        final c = centre.translate(dx * cw, dy * cw);
        final radius = r * cw;
        if (sunset > .05) {
          // the low sun lights the underside
          final rc = c.translate(0, radius * .18);
          final col = k(rim.withValues(alpha: a * .8 * sunset));
          paint.shader = ui.Gradient.radial(rc, radius, [col, col.withValues(alpha: 0)], const [0, 1]);
          canvas.drawCircle(rc, radius, paint);
        }
        final col = k(tint.withValues(alpha: a));
        paint.shader = ui.Gradient.radial(
          c,
          radius,
          [col, col.withValues(alpha: col.a * .55), col.withValues(alpha: 0)],
          const [0, .45, 1],
        );
        canvas.drawCircle(c, radius, paint);
      }
      final picture = recorder.endRecording();
      images.add(picture.toImageSync(iw, ih));
      picture.dispose();
    }
    return images;
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _smooth01(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// The colour of a gradient at [x] (0–1).
Color _sample(List<Color> colors, List<double> stops, double x) {
  if (x <= stops.first) return colors.first;
  for (var i = 0; i < stops.length - 1; i++) {
    if (x <= stops[i + 1]) return Color.lerp(colors[i], colors[i + 1], (x - stops[i]) / (stops[i + 1] - stops[i]))!;
  }
  return colors.last;
}

const List<double> _blendStops = [0, .2, .4, .6, .8, 1];

/// Two prayer times' skies, melted together.
SkyPalette blendPalettes(SkyBlend b) {
  final a = skyPalettes[b.from]!, c = skyPalettes[b.to]!;
  if (b.t <= 0 || b.from == b.to) return a;
  if (b.t >= 1) return c;
  Color mix(Color x, Color y) => Color.lerp(x, y, b.t)!;
  return SkyPalette(
    colors: [for (final x in _blendStops) mix(_sample(a.colors, a.stops, x), _sample(c.colors, c.stops, x))],
    stops: _blendStops,
    glow: mix(a.glow, c.glow),
    hazeA: mix(a.hazeA, c.hazeA),
    hazeB: mix(a.hazeB, c.hazeB),
    sun: mix(a.sun, c.sun),
    stars: _lerp(a.stars, c.stars, b.t),
    hill: mix(a.hill, c.hill),
  );
}

SkyBlend? _lastBlend;
SkyPalette? _lastPalette;

SkyPalette _paletteFor(SkyBlend b) {
  if (b != _lastBlend) {
    _lastBlend = b;
    _lastPalette = blendPalettes(b);
  }
  return _lastPalette!;
}

/// A gentle 0 → 1 → 0 wave with period [period].
double _wave(double seconds, double period, [double phase = 0]) =>
    .5 + .5 * math.sin(seconds / period * 2 * math.pi + phase);

/// Which part of the sky a painter draws. The parts that never move are kept apart from the moving one,
/// so only the moving one is painted again on each frame.
enum SkyLayer {
  /// The gradient of the sky, its haze, the faint stars and the Milky Way, the glow over the hills and the sun.
  back,

  /// What moves: the twinkling stars, shooting stars, the moon, clouds, birds, planes and fireflies.
  motion,

  /// The mountains and the lake (full screen), or the hills (card). Painted only when the light changes.
  land,

  /// The shade behind the numbers and the glass sheen.
  front,
}

/// What the sky shows, as picked in the settings.
class SkyOptions {
  const SkyOptions({this.landscape = true, this.life = true, this.fridayNight = false});

  /// The mountains and the lake under the full-screen sky.
  final bool landscape;

  /// Clouds, birds, planes, shooting stars and fireflies.
  final bool life;

  /// The night before Friday (Thursday evening until dawn): many more stars.
  final bool fridayNight;

  @override
  bool operator ==(Object other) =>
      other is SkyOptions && other.landscape == landscape && other.life == life && other.fridayNight == fridayNight;

  @override
  int get hashCode => Object.hash(landscape, life, fridayNight);
}

class SkyPainter extends CustomPainter {
  SkyPainter({
    required this.layer,
    required this.phase,
    required this.orb,
    required this.scene,
    required this.forbidden,
    required this.mode,
    required this.dark,
    required this.radius,
    this.clock,
    this.options = const SkyOptions(),
  }) : super(
         repaint: switch (layer) {
           SkyLayer.motion || SkyLayer.land => clock,
           SkyLayer.back || SkyLayer.front => null,
         },
       );

  final SkyLayer layer;
  final SkyPhase phase;
  final OrbState orb;

  /// The Moon and the scenes of the current hour.
  final SkyScene scene;
  final bool forbidden;
  final SkyMode mode;
  final bool dark;
  final double radius;

  /// The clock while the sky moves; null while it is still (switched off, resting, or out of sight). Still, it
  /// shows the moment it stopped at.
  final SkyClock? clock;

  final SkyOptions options;

  bool get _full => mode == SkyMode.full;

  /// The full-screen sky stands over the mountains and the lake.
  bool get _land => _full && options.landscape;

  /// Where the hills meet the sky: the sun and the moon rise and set behind them.
  double _horizon(Size size) {
    if (_land) return Landscape.horizonFor(size);
    final hh = _full ? math.min(.20 * size.height, 170.0) : math.min(.26 * size.height, 64.0);
    return size.height - hh * .45;
  }

  /// How much of a disc at [c] shows above the hills: 1 above, fading to 0 once it is behind them.
  double _aboveHills(Size size, Offset c, double r) => (1 - (c.dy - _horizon(size) + r) / (3 * r)).clamp(0.0, 1.0);

  /// A point on the arc the sun and the moon travel, at [p] (0 rising – 1 setting; outside that, below the hills).
  Offset _arc(Size size, double p) {
    final horizon = _horizon(size);
    final peak = size.height * (_full ? .2 : .1);
    final sn = math.sin(math.pi * p);
    // climbs quickly out of the hills and then stays high, above the countdown
    final rise = sn <= 0 ? sn : math.pow(sn, .45).toDouble();
    final y = horizon - (horizon - peak) * rise;
    // low in the sky it stays near the edges, clear of the countdown
    return Offset((.5 - .42 * math.cos(math.pi * p)) * size.width, y);
  }

  Color _k(Color c) => dark ? _dim(c) : c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    final pal = _paletteFor(scene.blend);
    switch (layer) {
      case SkyLayer.back:
        canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [for (final c in pal.colors) _k(c)], pal.stops),
        );
        _hourTint(canvas, size);
        _haze(canvas, size, pal);
        _horizonHaze(canvas, size, pal);
        if (_full) {
          _faintStars(canvas, size, pal);
          _milkyWay(canvas, size, pal);
          _paintStars(canvas, size, pal, 0, twinkling: false);
        }
        // the glows of the hour don't move between two minutes, so they are part of the still picture too (they
        // are blended in a way that would cost a second pass over the screen on every frame)
        _horizonGlow(canvas, size);
        _paintSun(canvas, size, pal);
      case SkyLayer.motion:
        // still, the sky shows the moment it stopped at
        final t = SkyClock.shared.seconds;
        final live = clock != null;
        final life = options.life;
        _paintStars(canvas, size, pal, t, twinkling: true);
        if (_full && live && life) _shootingStar(canvas, size, pal, t);
        _paintMoon(canvas, size, t);
        if (_full) _brightStar(canvas, size, t);
        if (_full && life) _paintClouds(canvas, size, t);
        if (_full && live && life) {
          _birds(canvas, size, t);
          _plane(canvas, size, t);
          _nightPlane(canvas, size, t);
        }
        if (_full && life && !_land) _paintFireflies(canvas, size, t);
      case SkyLayer.land:
        final t = clock?.seconds ?? 0.0;
        if (_land) {
          Landscape(size: size, pal: pal, scene: scene, dim: _k, t: t).paint(canvas);
        } else {
          _hills(canvas, size, pal);
        }
      case SkyLayer.front:
        _veil(canvas, size);
        // glass sheen along the top edge
        canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h * .38), [
              _k(const Color(0x29FFFFFF)),
              const Color(0x00FFFFFF),
            ]),
        );
        if (radius > 0) {
          // a 1px highlight inside the top edge
          final rr = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
          final edge = Path.combine(
            PathOperation.difference,
            Path()..addRRect(rr),
            Path()..addRRect(rr.shift(const Offset(0, 1))),
          );
          canvas.drawPath(edge, Paint()..color = const Color(0x38FFFFFF));
        }
    }
  }

  /// Two soft clouds of colour over the sky. They stay where they are: drifting, they were too slow to see and
  /// cost a large picture on every frame.
  void _haze(Canvas canvas, Size size, SkyPalette pal) {
    final w = size.width, h = size.height;
    final box = Rect.fromLTWH(-.35 * w, -.35 * h, 1.7 * w, 1.7 * h);
    _cloud(canvas, box, .24, .32, .38, .34, _k(pal.hazeA));
    _cloud(canvas, box, .78, .66, .44, .40, _k(pal.hazeB));
  }

  void _cloud(Canvas canvas, Rect box, double cx, double cy, double rx, double ry, Color color) {
    final c = Offset(box.left + cx * box.width, box.top + cy * box.height);
    final radiusX = rx * box.width, radiusY = ry * box.height;
    final m = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(1, radiusY / radiusX, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
    canvas.drawOval(
      Rect.fromCenter(center: c, width: radiusX * 1.4, height: radiusY * 1.4),
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          radiusX,
          [color, color.withValues(alpha: 0)],
          const [0, .7],
          TileMode.clamp,
          m.storage,
        ),
    );
  }

  /// Clouds that change with the hour: a few thin wisps in the morning, fuller clouds in the afternoon, and
  /// edges lit pink and gold around sunrise and sunset. None at night.
  ///
  /// Each cloud is painted once into a picture (again only when the hour changes its look), and a frame just
  /// moves the pictures across the sky.
  void _paintClouds(Canvas canvas, Size size, double t) {
    final cover = scene.cloudCover;
    if (cover <= .01) return;
    final w = size.width, h = size.height;
    final images = _CloudImages.of(w, scene, dark ? _k : null);
    final paint = Paint()..filterQuality = FilterQuality.low;
    for (var i = 0; i < images.length; i++) {
      final image = images[i];
      final (cy, scale0, crossing, offset) = _clouds[i];
      final cw = w * .55 * scale0 * (.75 + .45 * cover);
      final span = w + 2 * cw;
      final cx = ((offset + t / crossing) % 1.0) * span - cw;
      canvas.drawImage(image, Offset(cx - image.width / 2, cy * h * .7 - image.height / 2), paint);
    }
  }

  /// The stars: the [twinkling] ones on every frame, the others once, at their average brightness.
  void _paintStars(Canvas canvas, Size size, SkyPalette pal, double t, {required bool twinkling}) {
    if (pal.stars <= 0) return;
    final w = size.width, h = size.height;
    final paint = Paint()..isAntiAlias = true;
    final white = _k(const Color(0xFFFFFFFF));

    if (_full) {
      final floor = _horizon(size);
      // the night before Friday: the sky is full of stars
      final friday = options.fridayNight;
      final boost = friday ? math.max(scene.starBoost, .85) : scene.starBoost;
      final wash = _moonWash;
      final count = friday ? _fieldStars.length : _baseStars + (_deepStars * boost).round();
      for (var i = 0; i < count; i++) {
        final st = _fieldStars[i];
        if (st.twinkles != twinkling) continue;
        final p = Offset(st.x * w, st.y * floor);
        // a soft twinkle: mostly steady, with gentle dips, every star on its own beat (on average, a wave² of 3/8)
        final wave = _wave(t, st.period, st.phase);
        final tw = 1 - st.depth * .7 * (twinkling ? wave * wave : .375);
        final extra = i >= _baseStars + _deepStars ? 1.0 : (i >= _baseStars ? boost : 1.0);
        final a =
            (pal.stars *
                    st.bright *
                    tw *
                    _thickAir(p.dy, floor, h) *
                    extra *
                    (st.bright > .7 ? 1.0 : wash) *
                    (1 + .15 * boost))
                .clamp(0.0, 1.0);
        if (a <= .02) continue;
        final tint = _k(st.tint);
        if (st.r > .7) {
          // the brighter ones have a soft halo
          paint.color = tint.withValues(alpha: a * .1);
          canvas.drawCircle(p, st.r * 3, paint);
        }
        paint.color = tint.withValues(alpha: a);
        canvas.drawCircle(p, st.r, paint);
      }
      return;
    }

    if (!twinkling) return;
    final boxH = h * .70;
    var i = 0;
    for (final (sx, sy, r) in _stars) {
      final x = sx / 100 * w, y = sy / 100 * boxH;
      final fade = y <= .55 * boxH ? 1.0 : 1 - (y - .55 * boxH) / (.45 * boxH);
      // each star twinkles on its own beat
      final twinkle = 1 - .6 * _wave(t, 2.2 + (i * 7 % 5) * .45, i * 1.7);
      paint.color = white.withValues(alpha: (pal.stars * twinkle * fade).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), math.max(.6, r / 2), paint);
      i++;
    }
  }

  /// A bright moon washes out the faintest stars.
  double get _moonWash => scene.moon.up ? 1 - .4 * scene.moon.illumination : 1.0;

  /// Low over the mountains the air is thicker, and the stars there are dimmer.
  double _thickAir(double y, double floor, double h) => .3 + .7 * _smooth01((floor - y) / (.24 * h));

  /// The countless faint stars, all over the sky down to the mountains.
  void _faintStars(Canvas canvas, Size size, SkyPalette pal) {
    if (pal.stars <= 0) return;
    final w = size.width, h = size.height, floor = _horizon(size);
    final boost = options.fridayNight ? 1.0 : scene.starBoost;
    final count = _baseDust + ((_dust.length - _baseDust) * boost).round();
    final wash = _moonWash;
    final white = _k(const Color(0xFFF2F5FF));
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final (x, y, r, b) = _dust[i];
      final p = Offset(x * w, y * floor);
      final a = pal.stars * b * wash * _thickAir(p.dy, floor, h) * (i >= _baseDust ? boost : 1);
      if (a <= .02) continue;
      paint.color = white.withValues(alpha: a);
      canvas.drawCircle(p, r, paint);
    }
  }

  /// The paler sky just over the mountains: thick air lit by the towns at night, a white haze by day, warm at
  /// sunrise and sunset. A bright moon lights it more.
  void _horizonHaze(Canvas canvas, Size size, SkyPalette pal) {
    final h = size.height, horizon = _horizon(size);
    final moon = scene.moon.up ? scene.moon.illumination : 0.0;
    final a = (_full ? 1.0 : .7) * (.24 + .04 * (1 - pal.stars) + .08 * moon * pal.stars);
    final c = _k(pal.horizonHaze);
    final top = horizon - h * (_full ? .36 : .5);
    canvas.drawRect(
      Rect.fromLTRB(0, top, size.width, h),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, top),
          Offset(0, horizon),
          [c.withValues(alpha: 0), c.withValues(alpha: a * .3), c.withValues(alpha: a)],
          const [0, .6, 1],
        ),
    );
  }

  /// Now and then a star falls across the night sky.
  void _shootingStar(Canvas canvas, Size size, SkyPalette pal, double t) {
    if (pal.stars < .5) return;
    // more of them deep in the night
    final every = options.fridayNight ? 4.5 : (scene.starBoost > .5 ? 7.0 : 11.0);
    const lasts = .9;
    final n = (t / every).floor();
    final local = t - n * every;
    if (local > lasts) return;
    final rnd = math.Random(n * 7919 + 13);
    if (rnd.nextDouble() < .5) return; // not every time
    final w = size.width, h = size.height;
    final start = Offset((.25 + rnd.nextDouble() * .7) * w, (.04 + rnd.nextDouble() * .28) * h);
    final angle = (150 + rnd.nextDouble() * 25) * math.pi / 180; // down and to the left
    final dir = Offset(math.cos(angle), math.sin(angle));
    final travel = w * (.35 + rnd.nextDouble() * .2);
    final p = Curves.easeOutCubic.transform(local / lasts);
    final head = start + dir * (travel * p);
    final tail = head - dir * (40 + 45 * math.sin(math.pi * p));
    final alpha = math.sin(math.pi * (local / lasts)) * pal.stars * .55;
    final white = _k(const Color(0xFFFFFFFF));
    canvas.drawLine(
      tail,
      head,
      Paint()
        ..strokeWidth = .9
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(tail, head, [white.withValues(alpha: 0), white.withValues(alpha: alpha)]),
    );
  }

  /// The sun with its soft glow.
  void _paintSun(Canvas canvas, Size size, SkyPalette pal) {
    final p = scene.sunProgress;
    if (p < -.06 || p > 1.06) return; // well below the hills
    final c = _arc(size, p);
    final r = (_full ? 300.0 : 220.0) / 2;
    final s = _k(pal.sun);
    final above = _aboveHills(size, c, 14);
    if (above <= 0) return;
    Color a(double o) => s.withValues(alpha: o * above);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = ui.Gradient.radial(
          c,
          r,
          [a(.95), a(.95), a(.5), a(.26), a(.13), a(.05), a(.015), a(0)],
          const [0, .085, .10, .16, .28, .50, .72, .92],
        ),
    );
  }

  /// The Moon where it really is, in its real phase: it rises from behind the hills on the left, crosses the sky
  /// and sets behind the hills on the right, lit on the right while it grows and on the left while it wanes, with
  /// the faint earthshine on its dark part at night. By day it is a pale ghost. On new-moon nights only its faint
  /// outline shows, low in the west where it really is, near the sun.
  void _paintMoon(Canvas canvas, Size size, double t) {
    final moon = scene.moon;
    final night = scene.sunProgress < 0 || scene.sunProgress > 1;
    final k = moon.illumination;
    final p = moon.progress;
    final r = _full ? 17.0 : 13.0;
    final light = _k(const Color(0xFFF6F1DE));
    if (k < .015) {
      if (!night) return;
      // new moon: the dark disc, just caught by a little light
      final c = Offset(.86 * size.width, _horizon(size) - (_full ? 46 : 20));
      canvas.drawCircle(
        c,
        r * 4,
        Paint()..shader = ui.Gradient.radial(c, r * 4, [light.withValues(alpha: .06), light.withValues(alpha: 0)]),
      );
      canvas.drawCircle(c, r, Paint()..color = _k(const Color(0xFF9AA6C8)).withValues(alpha: .12));
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..color = light.withValues(alpha: .35),
      );
      return;
    }
    if (p < -.06 || p > 1.06) return; // below the hills
    final c = _arc(size, p);
    final above = _aboveHills(size, c, r);
    if (above <= 0) return;
    final alpha = (night ? 1.0 : .62) * above;

    if (night) {
      // the glow grows with the lit part
      final glowR = (_full ? 150.0 : 110.0) * (.55 + .45 * k) * (_full ? 1 + .06 * _wave(t, 7) : 1.0);
      canvas.drawCircle(
        c,
        glowR,
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            glowR,
            [
              light.withValues(alpha: (.05 + .13 * k) * above),
              light.withValues(alpha: (.03 + .06 * k) * above),
              light.withValues(alpha: (.01 + .02 * k) * above),
              light.withValues(alpha: 0),
            ],
            const [0, .18, .42, .75],
          ),
      );
      // earthshine: the unlit part is just visible
      canvas.drawCircle(c, r, Paint()..color = _k(const Color(0xFF9AA6C8)).withValues(alpha: .10 * (1 - k) * above));
    }

    // the lit part: the bright edge is a half circle, the shadow's edge a half ellipse
    final side = moon.waxing ? 1.0 : -1.0;
    final bulge = 1 - 2 * k;
    const steps = 28;
    final lit = Path();
    for (var i = 0; i <= steps; i++) {
      final a = -math.pi / 2 + math.pi * i / steps;
      final p = c.translate(side * r * math.cos(a), r * math.sin(a));
      i == 0 ? lit.moveTo(p.dx, p.dy) : lit.lineTo(p.dx, p.dy);
    }
    for (var i = steps; i >= 0; i--) {
      final a = -math.pi / 2 + math.pi * i / steps;
      lit.lineTo(c.dx + side * r * math.cos(a) * bulge, c.dy + r * math.sin(a));
    }
    lit.close();

    canvas.save();
    // the lit side leans towards the sun, which is below the horizon
    canvas.translate(c.dx, c.dy);
    canvas.rotate(side * -12 * math.pi / 180);
    canvas.translate(-c.dx, -c.dy);
    canvas.drawPath(
      lit,
      Paint()
        ..color = light.withValues(alpha: alpha)
        ..isAntiAlias = true,
    );
    // the dark seas of the Moon, only on the lit part
    canvas.clipPath(lit);
    final sea = Paint()..color = _k(const Color(0xFF8E8A7C)).withValues(alpha: .13 * alpha);
    canvas.drawCircle(c.translate(-r * .28, -r * .3), r * .3, sea);
    canvas.drawCircle(c.translate(r * .25, -r * .1), r * .22, sea);
    canvas.drawCircle(c.translate(-r * .05, r * .35), r * .2, sea);
    canvas.drawCircle(c.translate(r * .42, r * .38), r * .12, sea);
    canvas.restore();
  }

  /// A warm glow along the hills while the sun rises or sets, and a pale one where the moon is about to rise.
  void _horizonGlow(Canvas canvas, Size size) {
    final w = size.width, horizon = _horizon(size);
    void glow(double x, double strength, Color color, double width, double height) {
      if (strength <= .01) return;
      final c = Offset(x * w, horizon);
      final rx = w * width, ry = size.height * height;
      final m = Matrix4.identity()
        ..translateByDouble(c.dx, c.dy, 0, 1)
        ..scaleByDouble(1, ry / rx, 1, 1)
        ..translateByDouble(-c.dx, -c.dy, 0, 1);
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = ui.Gradient.radial(
            c,
            rx,
            [color.withValues(alpha: strength), color.withValues(alpha: strength * .35), color.withValues(alpha: 0)],
            const [0, .4, 1],
            TileMode.clamp,
            m.storage,
          ),
      );
    }

    // sunrise and sunset
    final sp = scene.sunProgress;
    final edge = math.min((sp - 0).abs(), (sp - 1).abs());
    if (edge < .12) {
      glow(
        .5 - .42 * math.cos(math.pi * sp.clamp(-.05, 1.05)),
        .42 * (1 - edge / .12),
        _k(const Color(0xFFFF9A5C)),
        .75,
        .2,
      );
    }
    // just before moonrise (only where the night is dark enough to see it)
    final moon = scene.moon;
    final mp = moon.progress;
    if (moon.illumination >= .015 && mp > -.2 && mp < -.02 && (sp < -.04 || sp > 1.04)) {
      final s = _smooth01((mp + .2) / .14) * (.4 + .6 * moon.illumination);
      glow(.08, .22 * s, _k(const Color(0xFFE6ECFF)), .45, .14);
    }
  }

  /// The colour of the hour, laid softly over the sky.
  void _hourTint(Canvas canvas, Size size) {
    final s = scene.tintStrength * (_full ? 1 : .7);
    if (s <= 0) return;
    final c = _k(Color(scene.tint));
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          [c.withValues(alpha: s * .55), c.withValues(alpha: s), c.withValues(alpha: s * .7)],
          const [0, .6, 1],
        ),
    );
  }

  /// The Milky Way: faint, uneven clouds of light across the sky in the darkest hours, with its dust of stars.
  void _milkyWay(Canvas canvas, Size size, SkyPalette pal) {
    final m = scene.milkyWay * pal.stars * (scene.moon.up ? 1 - .6 * scene.moon.illumination : 1);
    if (m <= .02) return;
    final w = size.width, h = size.height;
    final from = Offset(-.1 * w, .56 * h), to = Offset(1.1 * w, .02 * h);
    final dir = to - from;
    final len = dir.distance;
    final u = dir / len;
    final n = Offset(-u.dy, u.dx);
    final half = math.min(w, h) * .16;
    final angle = math.atan2(u.dy, u.dx);
    final glow = _k(const Color(0xFFD6DCF2));
    for (final (along, across, s, b) in _milkyClouds) {
      final c = from + u * (along * len) + n * (across * half);
      final rx = half * 1.5 * s, ry = half * .55 * s;
      final shape = Matrix4.identity()
        ..translateByDouble(c.dx, c.dy, 0, 1)
        ..rotateZ(angle)
        ..scaleByDouble(1, ry / rx, 1, 1)
        ..translateByDouble(-c.dx, -c.dy, 0, 1);
      canvas.drawCircle(
        c,
        rx * 1.05,
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            rx,
            [glow.withValues(alpha: .075 * b * m), glow.withValues(alpha: .03 * b * m), glow.withValues(alpha: 0)],
            const [0, .45, 1],
            TileMode.clamp,
            shape.storage,
          ),
      );
    }
    final dust = Paint();
    final white = _k(const Color(0xFFEAEFFF));
    final floor = _horizon(size);
    for (final (along, across, r, b) in _milkyDust) {
      final p = from + u * (along * len) + n * (across * half * .9);
      if (p.dy > floor) continue;
      dust.color = white.withValues(alpha: b * .5 * m * _thickAir(p.dy, floor, h));
      canvas.drawCircle(p, r, dust);
    }
  }

  /// The morning star before sunrise (in the east) and the evening star after sunset (in the west).
  void _brightStar(Canvas canvas, Size size, double t) {
    final s = scene.brightStar;
    if (s <= .02) return;
    final w = size.width, h = size.height;
    final morning = scene.hour < 12;
    final p = Offset((morning ? .1 : .9) * w, h * .7);
    final white = _k(const Color(0xFFFFF8EC));
    final pulse = .85 + .15 * _wave(t, 2.6);
    canvas.drawCircle(p, 9, Paint()..color = white.withValues(alpha: .10 * s * pulse));
    final ray = Paint()
      ..strokeWidth = .8
      ..strokeCap = StrokeCap.round
      ..color = white.withValues(alpha: .5 * s * pulse);
    final len = 6 + 3 * pulse;
    canvas.drawLine(p.translate(-len, 0), p.translate(len, 0), ray);
    canvas.drawLine(p.translate(0, -len), p.translate(0, len), ray);
    canvas.drawCircle(p, 1.8, Paint()..color = white.withValues(alpha: s));
  }

  /// A small flock in a loose V, out in the morning and home in the evening.
  void _birds(Canvas canvas, Size size, double t) {
    final s = scene.birds;
    if (s <= .02) return;
    const every = 46.0, crossing = 30.0;
    final n = (t / every).floor();
    final local = t - n * every;
    if (local > crossing) return;
    final rnd = math.Random(n * 4513 + 7);
    final w = size.width, h = size.height;
    final morning = scene.hour < 12;
    final p = local / crossing;
    final x = morning ? -.15 + 1.3 * p : 1.15 - 1.3 * p;
    final y = (.2 + rnd.nextDouble() * .25) * h + math.sin(p * math.pi * 2) * 6;
    final color = _k(orb.sun ? const Color(0xFF1E2438) : const Color(0xFF0E0F1E)).withValues(alpha: .55 * s);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final count = 4 + rnd.nextInt(4);
    final back = morning ? -1.0 : 1.0;
    for (var i = 0; i < count; i++) {
      final row = (i + 1) ~/ 2, side = i.isOdd ? -1.0 : 1.0;
      final c = Offset(x * w + back * row * 14, y + side * row * 9 + rnd.nextDouble() * 3);
      final flap = math.sin(t * 9 + i * 1.3);
      final span = 5.0 + rnd.nextDouble() * 1.5;
      final lift = 2.5 * flap;
      final path = Path()
        ..moveTo(c.dx - span, c.dy - lift)
        ..quadraticBezierTo(c.dx - span * .4, c.dy - lift * .3 - 1.2, c.dx, c.dy)
        ..quadraticBezierTo(c.dx + span * .4, c.dy - lift * .3 - 1.2, c.dx + span, c.dy - lift);
      canvas.drawPath(path, paint);
    }
  }

  /// A plane high up in the day sky, leaving a thin trail that slowly fades.
  void _plane(Canvas canvas, Size size, double t) {
    final s = scene.plane;
    if (s <= .02) return;
    const every = 80.0, crossing = 55.0;
    final n = (t / every).floor();
    final local = t - n * every;
    if (local > crossing + 12) return;
    final rnd = math.Random(n * 2861 + 3);
    if (rnd.nextDouble() < .35) return; // not every time
    final w = size.width, h = size.height;
    final ltr = rnd.nextBool();
    final y0 = (.08 + rnd.nextDouble() * .22) * h, y1 = y0 + (rnd.nextDouble() - .5) * .12 * h;
    Offset at(double p) => Offset((ltr ? -.05 + 1.1 * p : 1.05 - 1.1 * p) * w, y0 + (y1 - y0) * p);
    final p = (local / crossing).clamp(0.0, 1.0);
    final head = at(p);
    final tail = at(math.max(0, p - .35));
    final fade = local > crossing ? 1 - (local - crossing) / 12 : 1.0;
    final white = _k(const Color(0xFFFFFFFF));
    canvas.drawLine(
      tail,
      head,
      Paint()
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(tail, head, [
          white.withValues(alpha: 0),
          white.withValues(alpha: .35 * s * fade),
        ]),
    );
    if (local <= crossing) canvas.drawCircle(head, 1.3, Paint()..color = white.withValues(alpha: .8 * s));
  }

  /// A plane's lights blinking across the evening sky.
  void _nightPlane(Canvas canvas, Size size, double t) {
    final s = scene.nightPlane;
    if (s <= .02) return;
    const every = 95.0, crossing = 70.0;
    final n = (t / every).floor();
    final local = t - n * every;
    if (local > crossing) return;
    final rnd = math.Random(n * 1733 + 11);
    if (rnd.nextDouble() < .4) return;
    final w = size.width, h = size.height;
    final ltr = rnd.nextBool();
    final p = local / crossing;
    final y = (.1 + rnd.nextDouble() * .25) * h + p * 20;
    final c = Offset((ltr ? -.05 + 1.1 * p : 1.05 - 1.1 * p) * w, y);
    canvas.drawCircle(c, .9, Paint()..color = _k(const Color(0xFFFFFFFF)).withValues(alpha: .55 * s));
    final blink = (t * 1.1) % 1.0;
    if (blink < .12) {
      canvas.drawCircle(c, 3.2, Paint()..color = _k(const Color(0xFFFF5A5A)).withValues(alpha: .25 * s));
      canvas.drawCircle(c, 1.3, Paint()..color = _k(const Color(0xFFFF6B6B)).withValues(alpha: .95 * s));
    } else if (blink > .5 && blink < .58) {
      canvas.drawCircle(c, 3.0, Paint()..color = _k(const Color(0xFFFFFFFF)).withValues(alpha: .25 * s));
      canvas.drawCircle(c, 1.2, Paint()..color = _k(const Color(0xFFFFFFFF)).withValues(alpha: .95 * s));
    }
  }

  /// Fireflies drifting over the meadows on summer evenings.
  void _paintFireflies(Canvas canvas, Size size, double t) {
    final s = scene.fireflies;
    if (s <= .02) return;
    final w = size.width, h = size.height;
    final glow = _k(const Color(0xFFE8FF8A));
    final paint = Paint();
    for (final (x, y, speed, phase) in _fireflies) {
      final c = Offset(
        (x + .04 * math.sin(t * .3 * speed + phase)) * w,
        y * h + 12 * math.sin(t * .45 * speed + phase * 2),
      );
      final on = math.pow(math.max(0.0, math.sin(t * 1.3 * speed + phase)), 3).toDouble() * s;
      if (on < .03) continue;
      paint.color = glow.withValues(alpha: .18 * on);
      canvas.drawCircle(c, 5, paint);
      paint.color = glow.withValues(alpha: .9 * on);
      canvas.drawCircle(c, 1.4, paint);
    }
  }

  void _hills(Canvas canvas, Size size, SkyPalette pal) {
    final w = size.width, h = size.height;
    final hh = _full ? math.min(.20 * h, 170.0) : math.min(.26 * h, 64.0);
    const pad = 0.0;
    final sx = (w + 2 * pad) / 400, sy = hh / 60, top = h - hh;
    const far = Offset.zero, near = Offset.zero;
    // the season shows on the hills by day, and fades into the dark at night
    final base = _k(pal.hill);
    final daylight = 1 - pal.stars * .85;
    final hill = Color.lerp(base, _k(Color(scene.season)).withValues(alpha: base.a), .12 + .5 * daylight)!;
    void hillAt(Path path, Offset o, double alpha) {
      canvas.save();
      canvas.translate(-pad + o.dx, top + o.dy);
      canvas.scale(sx, sy);
      canvas.drawPath(
        path,
        Paint()
          ..color = hill.withValues(alpha: hill.a * alpha)
          ..isAntiAlias = true,
      );
      canvas.restore();
    }

    hillAt(_farHillPath, far, .55);
    // morning mist lying in the valley, between the far hills and the near ones
    if (_full && scene.mist > .02) {
      final mist = _k(const Color(0xFFF4F1F8));
      for (final (cx, cy, rx, a) in const [(.2, 30.0, .32, 1.0), (.62, 26.0, .4, .8), (.95, 32.0, .28, .9)]) {
        final c = Offset(cx * w, top + cy * sy) + far;
        final rect = Rect.fromCenter(center: c, width: rx * 2 * w, height: 22 * sy);
        canvas.drawOval(
          rect,
          Paint()
            ..shader = ui.Gradient.radial(
              c,
              rx * w,
              [mist.withValues(alpha: .34 * a * scene.mist), mist.withValues(alpha: 0)],
              const [0, 1],
              TileMode.clamp,
              (Matrix4.identity()
                    ..translateByDouble(c.dx, c.dy, 0, 1)
                    ..scaleByDouble(1, rect.height / rect.width, 1, 1)
                    ..translateByDouble(-c.dx, -c.dy, 0, 1))
                  .storage,
            ),
        );
      }
    }
    hillAt(_nearHillPath, near, 1);
    // the lit windows of the villages
    final lights = _full ? scene.townLights : 0.0;
    if (lights > .02) {
      final glow = Paint();
      final dot = Paint();
      for (final (x, y, warmth, order) in _windows) {
        if (order > lights) continue; // the windows go out one by one
        final c = Offset(x * sx - pad, top + y * sy) + near;
        final color = _k(Color.lerp(const Color(0xFFFFD27A), const Color(0xFFFFF2D2), warmth)!);
        glow.color = color.withValues(alpha: .16);
        canvas.drawCircle(c, 3.2, glow);
        dot.color = color.withValues(alpha: .9);
        canvas.drawCircle(c, .95, dot);
      }
    }
  }

  /// A gentle shade behind the numbers (so they stay crisp on the brightest skies); red while a prayer is forbidden.
  void _veil(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    void ellipse(double cx, double cy, double rx, double ry, double alpha) {
      final c = Offset(cx * w, cy * h);
      final radiusX = rx * w, radiusY = ry * h;
      final m = Matrix4.identity()
        ..translateByDouble(c.dx, c.dy, 0, 1)
        ..scaleByDouble(1, radiusY / radiusX, 1, 1)
        ..translateByDouble(-c.dx, -c.dy, 0, 1);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            radiusX,
            [Color.fromRGBO(0, 0, 0, alpha), const Color(0x00000000)],
            const [0, .78],
            TileMode.clamp,
            m.storage,
          ),
      );
    }

    if (_full) {
      ellipse(.5, .5, .70, .34, forbidden ? .16 : .20);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(0, h),
            const [Color(0x4D000000), Color(0x00000000), Color(0x00000000), Color(0x57000000)],
            const [0, .24, .70, 1],
          ),
      );
    } else {
      ellipse(.5, .52, .75, .55, forbidden ? .14 : .16);
    }
    if (forbidden) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [
            _k(const Color.fromRGBO(120, 18, 22, .72)),
            _k(const Color.fromRGBO(70, 8, 16, .82)),
          ]),
      );
    }
  }

  /// The still layers (see [StillSky]) are painted again only when this says so.
  @override
  bool shouldRepaint(SkyPainter old) =>
      old.layer != layer ||
      old.phase != phase ||
      old.forbidden != forbidden ||
      old.mode != mode ||
      old.dark != dark ||
      old.radius != radius ||
      old.scene != scene ||
      old.options != options ||
      (layer == SkyLayer.motion &&
          (old.clock != clock ||
              old.orb.sun != orb.sun ||
              old.orb.x != orb.x ||
              old.orb.y != orb.y ||
              old.orb.yFull != orb.yFull));
}

/// The card with the sky behind its content.
class SkyCard extends StatelessWidget {
  const SkyCard({
    super.key,
    required this.model,
    required this.mode,
    required this.clock,
    required this.child,
    this.options = const SkyOptions(),
    this.now,
  });

  final TodayModel model;
  final SkyMode mode;

  /// The moment now (today only): the small notes beside the Sun and the Moon are shown with it.
  final int Function()? now;

  /// The clock while the sky moves, or null while it is still.
  final SkyClock? clock;
  final Widget child;
  final SkyOptions options;

  /// Room around the card's halo for its blur to spread into.
  static const double _haloRoom = 90;

  @override
  Widget build(BuildContext context) {
    final dark = context.colors.dark;
    final pal = skyPalettes[model.phase]!;
    final forbidden = model.card?.forbidden ?? false;
    final full = mode == SkyMode.full;
    final radius = full ? 0.0 : 28.0;
    final nowFn = now;

    SkyPainter painter(SkyLayer l) => SkyPainter(
      layer: l,
      phase: model.phase,
      orb: model.orb,
      scene: model.scene,
      forbidden: forbidden,
      mode: mode,
      dark: dark,
      radius: radius,
      clock: clock,
      options: options,
    );

    // only the moving layer is painted on every frame; the ones under and over it are still pictures
    Widget card = Stack(
      fit: full ? StackFit.expand : StackFit.loose,
      children: [
        Positioned.fill(child: StillSky(painters: [painter(SkyLayer.back)])),
        Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: painter(SkyLayer.motion)))),
        Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: painter(SkyLayer.land)))),
        Positioned.fill(child: StillSky(painters: [painter(SkyLayer.front)])),
        child,
        if (nowFn != null && model.isToday)
          Positioned.fill(
            child: _OrbNotes(model: model, full: full, now: nowFn, painter: painter(SkyLayer.front)),
          ),
      ],
    );
    if (!full) card = ClipRRect(borderRadius: BorderRadius.circular(radius), child: card);
    if (full) return card;

    Widget halo = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: forbidden ? const Color(0xFF8C2A2A) : null,
        gradient: forbidden
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: pal.colors,
                stops: pal.stops,
              ),
      ),
    );
    if (dark) halo = ColorFiltered(colorFilter: _darkFilter, child: halo);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // blurred halo of the same sky, so the card glows into the page: blurred once into a picture (with room
        // around it for the blur), not again on every frame
        Positioned(
          left: 18 - _haloRoom,
          right: 18 - _haloRoom,
          top: 22 - _haloRoom,
          bottom: -12 - _haloRoom,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: _StillPicture(
                  stamp: (model.phase, dark, forbidden),
                  child: Padding(
                    padding: const EdgeInsets.all(_haloRoom),
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                      child: Opacity(opacity: dark ? .4 : .5, child: halo),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              const BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
              BoxShadow(
                color: pal.glow.withValues(alpha: .75),
                blurRadius: 44,
                spreadRadius: -20,
                offset: const Offset(0, 22),
              ),
            ],
          ),
          child: card,
        ),
      ],
    );
  }
}

/// Shows [child] as one picture, taken once, and again only when [stamp] changes (or the size does). For things
/// that never change between two of their builds, and cost much to draw (a blur).
class _StillPicture extends StatefulWidget {
  const _StillPicture({required this.stamp, required this.child});

  final Object stamp;
  final Widget child;

  @override
  State<_StillPicture> createState() => _StillPictureState();
}

class _StillPictureState extends State<_StillPicture> {
  final SnapshotController _snap = SnapshotController(allowSnapshotting: true);

  @override
  void didUpdateWidget(_StillPicture old) {
    super.didUpdateWidget(old);
    if (old.stamp != widget.stamp) _snap.clear();
  }

  @override
  void dispose() {
    _snap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SnapshotWidget(controller: _snap, mode: SnapshotMode.permissive, autoresize: true, child: widget.child);
}

/// A soft wash of the current sky behind the whole page:
/// CSS `radial-gradient(70% 60% at 50% 22%, glow, transparent 72%)` over the top 75% of the screen.
class PageGlow extends StatelessWidget {
  const PageGlow({super.key, required this.phase});

  final SkyPhase phase;

  @override
  Widget build(BuildContext context) {
    final dark = context.colors.dark;
    final glow = skyPalettes[phase]!.glow;
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: MediaQuery.sizeOf(context).height * .75,
      child: IgnorePointer(
        child: Opacity(
          opacity: dark ? .26 : .2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -.56),
                radius: 1,
                colors: [glow, glow.withValues(alpha: 0)],
                stops: const [0, .72],
                transform: const _EllipseTransform(.7, .6, .22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Turns a unit radial gradient into an ellipse with radii [rx]·width and [ry]·height,
/// centred [cy]·height from the top.
class _EllipseTransform extends GradientTransform {
  const _EllipseTransform(this.rx, this.ry, this.cy);

  final double rx;
  final double ry;
  final double cy;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final shortest = bounds.shortestSide;
    final cx = bounds.center.dx;
    final y = bounds.top + bounds.height * cy;
    return Matrix4.identity()
      ..translateByDouble(cx, y, 0, 1)
      ..scaleByDouble(rx * bounds.width / shortest, ry * bounds.height / shortest, 1, 1)
      ..translateByDouble(-cx, -y, 0, 1);
  }
}

const List<Shadow> _noteShadow = [Shadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 3)];

/// Small notes that travel with the Sun and the Moon across the sky: the UV beside the Sun, the phase beside the
/// Moon. A tap on a note, or on the Sun or the Moon, tells more.
class _OrbNotes extends StatefulWidget {
  const _OrbNotes({required this.model, required this.full, required this.now, required this.painter});

  final TodayModel model;
  final bool full;
  final int Function() now;

  /// Where the Sun and the Moon are drawn, so the notes keep to them.
  final SkyPainter painter;

  @override
  State<_OrbNotes> createState() => _OrbNotesState();
}

class _OrbNotesState extends State<_OrbNotes> {
  /// Where the texts on the screen are (the prayer, the countdown, the date…): a note never covers them.
  List<Rect>? _texts;

  /// After each frame: finds every text on the screen and keeps where it is, so the notes find a free place.
  void _measure() {
    if (!mounted) return;
    final me = context.findRenderObject();
    if (me is! RenderBox || !me.attached || !me.hasSize) return;
    RenderObject root = me;
    while (root.parent != null) {
      root = root.parent!;
    }
    final origin = me.localToGlobal(Offset.zero);
    final bounds = Offset.zero & me.size;
    final found = <Rect>[];
    void visit(RenderObject o) {
      if (identical(o, me)) return;
      if (o is RenderOffstage && o.offstage) return;
      if (o is RenderOpacity && o.opacity == 0) return;
      if (o is RenderParagraph) {
        if (o.hasSize && o.text.toPlainText().trim().isNotEmpty) {
          final r = (o.localToGlobal(Offset.zero) - origin) & o.size;
          if (r.overlaps(bounds)) found.add(r);
        }
        return;
      }
      o.visitChildren(visit);
    }

    root.visitChildren(visit);
    final old = _texts;
    final same =
        old != null &&
        old.length == found.length &&
        Iterable<int>.generate(found.length).every((i) {
          final a = old[i], b = found[i];
          return (a.left - b.left).abs() < 2 && (a.top - b.top).abs() < 2 && (a.width - b.width).abs() < 2;
        });
    if (!same) setState(() => _texts = found);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final texts = _texts;
    if (texts == null) return const SizedBox.expand();
    final model = widget.model, full = widget.full, painter = widget.painter;
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        if (!size.isFinite || size.isEmpty) return const SizedBox.shrink();
        final t = widget.now();
        final scene = model.scene;
        final r = full ? 17.0 : 13.0;
        // (where, one line, short form for two lines, sun)
        final notes = <(Offset, String, String, bool)>[];
        final sp = scene.sunProgress;
        if (sp > 0 && sp < 1) {
          final c = painter._arc(size, sp);
          if (painter._aboveHills(size, c, 14) > .5) {
            final uv = uvIndex(t), level = uvLevel(uv).level;
            notes.add((c, 'UV $uv · $level', 'UV $uv\n$level', true));
          }
        }
        final moon = scene.moon;
        Offset? mc;
        if (moon.illumination < .015) {
          if (sp < 0 || sp > 1) mc = Offset(.86 * size.width, painter._horizon(size) - (full ? 46 : 20));
        } else if (moon.progress > 0 && moon.progress < 1) {
          final c = painter._arc(size, moon.progress);
          if (painter._aboveHills(size, c, r) > .5) mc = c;
        }
        if (mc != null) {
          final pct = (moon.illumination * 100).round();
          final name = moonPhaseName(moon.illumination, moon.waxing);
          notes.add((mc, '$name · $pct%', '$name\n$pct%', false));
        }
        if (notes.isEmpty) return const SizedBox.shrink();

        final style = vt(
          full ? 11.5 : 10.5,
          750,
          color: const Color(0xFFFFFFFF),
          opacity: .92,
          height: 1.2,
          shadows: _noteShadow,
        );
        final inside = (Offset.zero & size).deflate(6);
        final busy = [for (final x in texts) x.inflate(6)];
        final children = <Widget>[];
        for (final n in notes) {
          final c = n.$1;
          final gap = r + 7;
          // the free place nearest to it: beside it, under, over, then the corners; in one line, else in two
          (Rect, String)? spot;
          for (final text in [n.$2, n.$3]) {
            final tp = TextPainter(
              text: TextSpan(text: text, style: style),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              textScaler: scaler,
            )..layout();
            final w = tp.width + 14, h = tp.height + 6;
            tp.dispose();
            final toEdge = c.dx < size.width / 2;
            final left = Offset(c.dx - gap - w, c.dy - h / 2), right = Offset(c.dx + gap, c.dy - h / 2);
            final candidates = [
              toEdge ? left : right,
              Offset(c.dx - w / 2, c.dy + gap),
              Offset(c.dx - w / 2, c.dy - gap - h),
              toEdge ? right : left,
              Offset(c.dx + gap * .7, c.dy + gap * .7),
              Offset(c.dx - gap * .7 - w, c.dy + gap * .7),
              Offset(c.dx + gap * .7, c.dy - gap * .7 - h),
              Offset(c.dx - gap * .7 - w, c.dy - gap * .7 - h),
            ];
            for (final o in candidates) {
              final rect = o & Size(w, h);
              final fits =
                  rect.left >= inside.left &&
                  rect.top >= inside.top &&
                  rect.right <= inside.right &&
                  rect.bottom <= inside.bottom;
              if (fits && !busy.any((b) => b.overlaps(rect))) {
                spot = (rect, text);
                break;
              }
            }
            if (spot != null) break;
          }
          final sun = n.$4;
          void open() {
            showSkyInfo(context, sun: sun, model: model, now: widget.now());
          }

          // the Sun or the Moon itself opens the same, with or without a note
          children.add(
            Positioned(
              left: c.dx - 22,
              top: c.dy - 22,
              width: 44,
              height: 44,
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: open),
            ),
          );
          if (spot == null) continue; // no free place: no note rather than one over the text
          busy.add(spot.$1.inflate(4));
          children.add(
            Positioned(
              left: spot.$1.left,
              top: spot.$1.top,
              child: Semantics(
                button: true,
                label: '${n.$2}. Më shumë për ${sun ? 'diellin' : 'hënën'}',
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: open,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: const BoxDecoration(
                      color: Color(0x2E000000),
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Text(spot.$2, style: style, textAlign: TextAlign.center, softWrap: false),
                  ),
                ),
              ),
            ),
          );
        }
        return Stack(children: children);
      },
    );
  }
}
