import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../logic/calendar_notes.dart';
import '../state/app_controller.dart';
import 'colors.dart';
import 'month_view.dart';
import 'next_card.dart';
import 'pulse.dart';
import 'settings.dart';
import 'sky.dart';
import 'svg_icon.dart';
import 'text.dart';
import 'today_view.dart';
import 'widgets.dart';

const double _wideBreakpoint = 900;
const double _maxContentWidth = 1120;

/// How far the sky is pulled down (in pixels) before letting go opens the month.
const double _monthPull = 90;

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller, this.skyMotion = true});

  final AppController controller;

  /// Whether the sky moves (tests turn it off, so the screen can settle).
  final bool skyMotion;

  @override
  State<HomePage> createState() => _HomePageState();
}

enum _Drag { none, ignored, sheet, month }

class _HomePageState extends State<HomePage> with WidgetsBindingObserver, TickerProviderStateMixin {
  late final SkyClock _sky = SkyClock(this);

  /// How far the prayer-times sheet of the full-screen sky is open, 0–1.
  late final AnimationController _sheet = AnimationController(vsync: this);
  final GlobalKey _sheetKey = GlobalKey();

  /// How far the sky is pulled down towards the month, in pixels.
  late final AnimationController _pull = AnimationController(
    vsync: this,
    lowerBound: 0,
    upperBound: 400,
    duration: const Duration(milliseconds: 220),
  );

  /// Each change of layout gets a key of its own, so going back to a layout that is still fading out
  /// (a quick tap back and forth) never puts two pages with the same key on the screen.
  String? _layout;
  int _switches = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.start();
    if (widget.skyMotion) _sky.start();
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.stop();
      widget.controller.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.stop();
    _sky.dispose();
    _sheet.dispose();
    _pull.dispose();
    super.dispose();
  }

  /// Stop ticking while the app is out of sight, and catch up as soon as it comes back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.start();
      if (widget.skyMotion) _sky.start();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      widget.controller.stop();
      _sky.stop();
    }
  }

  void _haptic() {
    if (widget.controller.on(Feature.haptics)) HapticFeedback.selectionClick();
  }

  // ---------- Swiping up and down on the full-screen sky ----------

  double get _sheetHeight =>
      (_sheetKey.currentContext?.size?.height ?? 0) > 0 ? _sheetKey.currentContext!.size!.height : 380;

  _Drag _drag = _Drag.none;
  bool _edgeDrag = false;

  /// A swipe that starts down at the bottom edge — the phone's own home gesture — doesn't open the sheet, so going
  /// to the home screen doesn't pull up the times by accident.
  void _downVertical(DragDownDetails d) {
    final mq = MediaQuery.of(context);
    final bottom = math.max(mq.systemGestureInsets.bottom, mq.padding.bottom) + 28;
    _edgeDrag = _sheet.value == 0 && d.globalPosition.dy > mq.size.height - bottom;
    _drag = _Drag.none;
  }

  void _updateVerticalDrag(DragUpdateDetails d) {
    final dy = d.primaryDelta!;
    if (_drag == _Drag.none) {
      // the first movement decides: up (or an open sheet) moves the sheet, down pulls the month
      if (_sheet.value > 0 || _sheet.isAnimating || dy < 0) {
        _drag = _edgeDrag ? _Drag.ignored : _Drag.sheet;
      } else {
        _drag = _Drag.month;
      }
    }
    switch (_drag) {
      case _Drag.sheet:
        _sheet.stop();
        _sheet.value = (_sheet.value - dy / _sheetHeight).clamp(0.0, 1.0);
      case _Drag.month:
        _pull.stop();
        _pull.value = (_pull.value + dy * .8).clamp(0.0, 400.0);
      case _Drag.none || _Drag.ignored:
        break;
    }
  }

  /// A flick decides; otherwise it goes to whichever side is nearer.
  void _endVerticalDrag(DragEndDetails d) {
    final vy = d.velocity.pixelsPerSecond.dy;
    switch (_drag) {
      case _Drag.sheet:
        final open = vy.abs() > 300 ? vy < 0 : _sheet.value > .4;
        _settleSheet(open, velocity: -vy / _sheetHeight);
      case _Drag.month:
        if (_pull.value >= _monthPull || (vy > 700 && _pull.value > 24)) {
          _openMonth();
        } else {
          _pull.animateTo(0, curve: Curves.easeOutCubic);
        }
      case _Drag.none || _Drag.ignored:
        break;
    }
    _drag = _Drag.none;
    _edgeDrag = false;
  }

  void _openMonth() {
    _haptic();
    _pull.value = 0;
    final c = widget.controller;
    // the month of the day shown
    c.select(c.selected);
    c.setView(HomeView.month);
  }

  /// Springs the sheet open or shut.
  void _settleSheet(bool open, {double velocity = 0}) {
    final target = open ? 1.0 : 0.0;
    if (_sheet.value == target && !_sheet.isAnimating) return;
    _sheet.animateWith(
      _ClampedSpring(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 320, damping: 34),
          _sheet.value,
          target,
          velocity,
          tolerance: const Tolerance(distance: .001, velocity: .01),
        ),
        target,
      ),
    );
  }

  // ---------- Swiping left and right through the days ----------

  double _dragX = 0;
  bool _sideDrag = false;

  void _downSide(DragDownDetails d) {
    final mq = MediaQuery.of(context);
    // the phone's back gesture lives at the left and right edges
    final edge = math.max(16.0, math.max(mq.systemGestureInsets.left, mq.systemGestureInsets.right) + 8);
    final x = d.globalPosition.dx;
    _sideDrag = _sheet.value == 0 && x > edge && x < mq.size.width - edge;
    _dragX = 0;
  }

  void _updateSideDrag(DragUpdateDetails d) {
    if (_sideDrag) _dragX += d.primaryDelta!;
  }

  /// Only a deliberate swipe changes the day: far enough across the screen, and quick enough (or very far).
  void _endSideDrag(DragEndDetails d) {
    if (!_sideDrag) return;
    _sideDrag = false;
    final width = MediaQuery.sizeOf(context).width;
    final vx = d.velocity.pixelsPerSecond.dx;
    final far = _dragX.abs() >= math.max(72, width * .2);
    final veryFar = _dragX.abs() >= width * .4;
    final quick = vx.abs() >= 450 && vx.sign == _dragX.sign;
    if (!(far && (quick || veryFar))) return;
    _haptic();
    widget.controller.stepDay(_dragX < 0 ? 1 : -1);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => c.stepDay(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => c.stepDay(1),
      },
      child: Focus(
        autofocus: true,
        child: ListenableBuilder(listenable: c, builder: (context, _) => _page(context, c)),
      ),
    );
  }

  Widget _page(BuildContext context, AppController c) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= _wideBreakpoint;
    final colors = context.colors;
    final model = c.model;
    final clock = MediaQuery.disableAnimationsOf(context) || !widget.skyMotion ? null : _sky;
    // on a phone, today is the sky itself; the times and the tips are swiped up over it, the month pulled down
    final fullSky = !wide && c.view == HomeView.today;
    if (!fullSky && (_sheet.value != 0 || _sheet.isAnimating)) {
      // the sheet starts closed the next time the sky fills the screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _sheet.stop();
        _sheet.value = 0;
      });
    }

    // The status bar takes the page colour, or the top of the sky when the sky fills the screen.
    final lightIcons = fullSky || colors.dark;
    final overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: lightIcons ? Brightness.light : Brightness.dark,
      statusBarBrightness: lightIcons ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: lightIcons ? Brightness.light : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    );

    final header = _Header(controller: c, onSky: fullSky, wide: wide);

    Widget body;
    String layout;
    if (wide) {
      layout = 'wide';
      body = Column(
        children: [
          header,
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 400,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: TodayPanel(controller: c, clock: clock),
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: _MonthHost(controller: c, onPick: () {}),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else if (fullSky) {
      layout = 'full';
      body = _fullSky(c, header, clock);
    } else {
      layout = 'month';
      body = _month(c, header);
    }

    final instant = MediaQuery.disableAnimationsOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: colors.bg,
        // the month slides down from the top over the sky, and back up again; the rest cross-fades
        body: AnimatedSwitcher(
          duration: instant ? Duration.zero : const Duration(milliseconds: 340),
          reverseDuration: instant ? Duration.zero : const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final key = (child.key as ValueKey<String>?)?.value ?? '';
            if (key.startsWith('month')) {
              return _MonthLayer(
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, -1), end: Offset.zero).animate(animation),
                  child: child,
                ),
              );
            }
            return FadeTransition(opacity: animation, child: child);
          },
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.expand,
            children: [
              // the month always slides over the sky, coming and going
              ...previous.where((w) => !_isMonth(w)),
              if (current != null && !_isMonth(current)) current,
              ...previous.where(_isMonth),
              if (current != null && _isMonth(current)) current,
            ],
          ),
          child: Stack(
            key: ValueKey(_switchKey(layout)),
            fit: StackFit.expand,
            children: [
              if (!fullSky) ColoredBox(color: colors.bg),
              if (!fullSky) PageGlow(phase: model.phase),
              body,
            ],
          ),
        ),
      ),
    );
  }

  static bool _isMonth(Widget w) => w is _MonthLayer || (w is KeyedSubtree && w.child is _MonthLayer);

  String _switchKey(String layout) {
    if (layout != _layout) {
      _layout = layout;
      _switches++;
    }
    return '$layout-$_switches';
  }

  /// How far the month has been pulled up past its end, in pixels.
  double _overscroll = 0;

  /// The month on a phone: pulled down over the sky, and pushed back up (or Back) to return.
  Widget _month(AppController c, Widget header) {
    void back() {
      _haptic();
      c.setView(HomeView.today);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Column(
        children: [
          header,
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                // pulling up past the end of the month goes back to the sky
                if (n is OverscrollNotification && n.dragDetails != null && n.overscroll > 0) {
                  _overscroll += n.overscroll;
                  if (_overscroll > 80) {
                    _overscroll = -1e9;
                    back();
                  }
                } else if (n is ScrollStartNotification) {
                  _overscroll = 0;
                }
                return false;
              },
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _MonthHost(controller: c, onPick: () => c.setView(HomeView.today)),
              ),
            ),
          ),
          _MonthFooter(onBack: back, hint: c.on(Feature.hints)),
        ],
      ),
    );
  }

  /// The sky fills the screen with only the countdown; the day's times are swiped up from the bottom, and
  /// swiped down again (or a tap on the sky, or Back) to hide them. Swiping down on the sky opens the month.
  Widget _fullSky(AppController c, Widget header, SkyClock? clock) {
    final fadeOut = ReverseAnimation(_sheet);
    final model = c.model;
    final hijri = hijriOf(c.selected, c.hijriAdj);
    final options = SkyOptions(
      landscape: c.on(Feature.landscape),
      mosque: c.on(Feature.mosque),
      life: c.on(Feature.skyLife),
      friday: model.friday && c.on(Feature.fridayLook),
      festive: hijri?.m == 9 || model.notes.any((n) => n.kind == NoteKind.islamic),
      topInset: MediaQuery.paddingOf(context).top,
    );
    final hints = c.on(Feature.hints);
    final alarm = c.on(Feature.homeAlarm) ? model.homeAlarm : null;
    final nafile = c.on(Feature.nafile) ? model.nafile : null;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return AnimatedBuilder(
      animation: _sheet,
      builder: (context, child) => PopScope(
        canPop: _sheet.value == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _settleSheet(false);
        },
        child: child!,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragDown: _downVertical,
        onVerticalDragUpdate: _updateVerticalDrag,
        onVerticalDragEnd: _endVerticalDrag,
        onVerticalDragCancel: () => _pull.animateTo(0),
        // swipe left for the next day, right for the day before: its sky, moon, sun and season at this hour
        onHorizontalDragDown: c.on(Feature.daySwipe) ? _downSide : null,
        onHorizontalDragUpdate: c.on(Feature.daySwipe) ? _updateSideDrag : null,
        onHorizontalDragEnd: c.on(Feature.daySwipe) ? _endSideDrag : null,
        onTap: () {
          if (_sheet.value > 0) _settleSheet(false);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // another day: its sky fades in over the last one
            FadeSwap(
              value: c.selected.epochDay,
              duration: const Duration(milliseconds: 280),
              expand: true,
              child: NextCard(
                model: model,
                now: c.viewNow,
                mode: SkyMode.full,
                clock: clock,
                countdownWeight: c.countdownWeight,
                reveal: _sheet,
                options: options,
              ),
            ),
            PrayerPulse(
              target: model.card?.target,
              now: c.now,
              enabled: clock != null && c.isToday && c.on(Feature.pulse),
            ),
            Column(
              children: [
                header,
                Expanded(
                  child: Stack(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 4, 16, 10 + bottomInset),
                        child: AnimatedBuilder(
                          animation: _pull,
                          builder: (context, child) {
                            // pulling down: everything follows the finger a little, and the month hint brightens
                            final v = _pull.value;
                            if (v == 0) return child!;
                            return Transform.translate(offset: Offset(0, 40 * (1 - math.exp(-v / 90))), child: child);
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FadeTransition(
                                opacity: fadeOut,
                                child: DateRow(controller: c, onSky: true),
                              ),
                              if (!c.isToday)
                                FadeTransition(
                                  opacity: fadeOut,
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: PillButton(label: 'Kthehu te sot', onTap: c.selectToday, onSky: true),
                                    ),
                                  ),
                                ),
                              if (hints)
                                FadeTransition(
                                  opacity: fadeOut,
                                  child: Center(child: MonthHint(onTap: _openMonth)),
                                ),
                              const Spacer(),
                              FadeTransition(
                                opacity: fadeOut,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (alarm != null) ...[HomeAlarm(alarm: alarm), const SizedBox(height: 8)],
                                    if (nafile != null) ...[NafileLine(hint: nafile), const SizedBox(height: 4)],
                                    if (hints) SwipeHint(onTap: () => _settleSheet(true)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: ClipRect(
                          child: LayoutBuilder(
                            builder: (context, box) => AnimatedBuilder(
                              animation: _sheet,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.bottomCenter,
                                child: SizedBox(
                                  width: box.maxWidth,
                                  child: Padding(
                                    padding: EdgeInsets.only(bottom: bottomInset),
                                    child: SkyTimesSheet(key: _sheetKey, controller: c),
                                  ),
                                ),
                              ),
                              builder: (context, sheet) {
                                final v = _sheet.value;
                                if (v == 0) return const SizedBox.shrink();
                                return Align(
                                  alignment: Alignment.bottomCenter,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(maxHeight: box.maxHeight),
                                    child: FractionalTranslation(translation: Offset(0, 1 - v), child: sheet),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Marks the month's page, so it always slides over the sky.
class _MonthLayer extends StatelessWidget {
  const _MonthLayer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// The month table, built again only when what it shows changes (not on every tick of the clock).
class _MonthHost extends StatefulWidget {
  const _MonthHost({required this.controller, required this.onPick});

  final AppController controller;
  final VoidCallback onPick;

  @override
  State<_MonthHost> createState() => _MonthHostState();
}

class _MonthHostState extends State<_MonthHost> {
  String? _key;
  Widget? _child;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final key =
        '${c.cursorY}-${c.cursorM}-${c.today}-${c.selected}-${c.city.id}-${c.hijriAdj}-${c.settingsVersion.value}';
    if (key != _key || _child == null) {
      _key = key;
      _child = MonthPanel(controller: c, onPick: widget.onPick);
    }
    return _child!;
  }
}

/// The bottom of the month on a phone: a still arrow and the way back to the sky.
class _MonthFooter extends StatelessWidget {
  const _MonthFooter({required this.onBack, required this.hint});

  final VoidCallback onBack;
  final bool hint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // a swipe up on the footer goes back too
      onVerticalDragEnd: (d) {
        if (d.velocity.pixelsPerSecond.dy < -200) onBack();
      },
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + bottom),
        decoration: BoxDecoration(
          color: c.bg.withValues(alpha: .94),
          border: Border(top: BorderSide(color: c.line)),
        ),
        child: Tap(
          onTap: onBack,
          label: 'Kthehu te qielli',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgIcon(VIcon.chevUp, size: 18, color: c.muted),
              Text(hint ? 'Rrëshqit lart për t\'u kthyer' : 'Kthehu', style: vt(13, 700, color: c.muted, height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A spring that never overshoots its end (the sheet would otherwise bounce past fully open or shut).
class _ClampedSpring extends Simulation {
  _ClampedSpring(this.spring, this.target);

  final SpringSimulation spring;
  final double target;

  @override
  double x(double time) => spring.isDone(time) ? target : spring.x(time).clamp(0.0, 1.0);

  @override
  double dx(double time) => spring.isDone(time) ? 0 : spring.dx(time);

  @override
  bool isDone(double time) => spring.isDone(time);
}

/// The brand, the city picker and the settings button.
class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.onSky, required this.wide});

  final AppController controller;
  final bool onSky;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, top + (wide ? 26 : 14), 16, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Brand(onSky: onSky),
              const SizedBox(width: 12),
              // the city pill shrinks (with an ellipsis) before anything overflows
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: CityPicker(city: controller.city, onSelected: controller.setCity, onSky: onSky),
                    ),
                    const SizedBox(width: 8),
                    RoundIconButton(
                      icon: VIcon.settings,
                      label: 'Cilësimet',
                      onSky: onSky,
                      onTap: () => showSettings(context, controller),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
