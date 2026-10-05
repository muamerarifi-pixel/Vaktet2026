import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../state/app_controller.dart';
import 'colors.dart';
import 'month_view.dart';
import 'next_card.dart';
import 'settings.dart';
import 'sky.dart';
import 'svg_icon.dart';
import 'text.dart';
import 'today_view.dart';
import 'widgets.dart';

const double _wideBreakpoint = 900;
const double _maxContentWidth = 1120;

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller, this.skyMotion = true});

  final AppController controller;

  /// Whether the sky moves (tests turn it off, so the screen can settle).
  final bool skyMotion;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver, TickerProviderStateMixin {
  late final SkyClock _sky = SkyClock(this);

  /// How far the prayer-times sheet of the full-screen sky is open, 0–1.
  late final AnimationController _sheet = AnimationController(vsync: this);
  final GlobalKey _sheetKey = GlobalKey();

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

  // ---------- The prayer-times sheet of the full-screen sky ----------

  double get _sheetHeight =>
      (_sheetKey.currentContext?.size?.height ?? 0) > 0 ? _sheetKey.currentContext!.size!.height : 380;

  /// The sheet follows the finger.
  /// Whether the current drag started in the bottom edge zone and is ignored.
  bool _edgeDrag = false;

  /// A swipe that starts down at the bottom edge — the tabs or the phone's own home gesture — doesn't open
  /// the sheet, so going to the home screen doesn't pull up the times by accident.
  void _startSheetDrag(DragStartDetails d) {
    final mq = MediaQuery.of(context);
    final edge = math.max(mq.systemGestureInsets.bottom, mq.padding.bottom) + 96;
    _edgeDrag = _sheet.value == 0 && d.globalPosition.dy > mq.size.height - edge;
  }

  void _dragSheet(DragUpdateDetails d) {
    if (_edgeDrag) return;
    _sheet.stop();
    _sheet.value = (_sheet.value - d.primaryDelta! / _sheetHeight).clamp(0.0, 1.0);
  }

  /// A flick decides; otherwise it goes to whichever side is nearer.
  void _endSheetDrag(DragEndDetails d) {
    if (_edgeDrag) {
      _edgeDrag = false;
      return;
    }
    final vy = d.velocity.pixelsPerSecond.dy;
    final open = vy.abs() > 300 ? vy < 0 : _sheet.value > .4;
    _settleSheet(open, velocity: -vy / _sheetHeight);
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
    // on a phone, today is the sky itself; the times and the tips are swiped up over it
    final fullSky = !wide && c.view == HomeView.today && c.isToday;
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
                          child: MonthPanel(controller: c, onPick: () {}),
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
      final today = c.view == HomeView.today;
      layout = today ? 'today' : 'month';
      body = Column(
        children: [
          header,
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: today
                  ? TodayPanel(controller: c, clock: clock)
                  : MonthPanel(controller: c, onPick: () => c.setView(HomeView.today)),
            ),
          ),
          _Tabs(controller: c, onSky: false),
        ],
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: colors.bg,
        // going to (or leaving) the full-screen sky, or to another tab: a short, light cross-fade
        body: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: Stack(
            key: ValueKey(_switchKey(layout)),
            fit: StackFit.expand,
            children: [
              if (!fullSky) PageGlow(phase: model.phase),
              body,
            ],
          ),
        ),
      ),
    );
  }

  String _switchKey(String layout) {
    if (layout != _layout) {
      _layout = layout;
      _switches++;
    }
    return '$layout-$_switches';
  }

  /// The sky fills the screen with only the countdown; the day's times are swiped up from the bottom, and
  /// swiped down again (or a tap on the sky, or Back) to hide them.
  Widget _fullSky(AppController c, Widget header, SkyClock? clock) {
    final fadeOut = ReverseAnimation(_sheet);
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
        onVerticalDragStart: _startSheetDrag,
        onVerticalDragUpdate: _dragSheet,
        onVerticalDragEnd: _endSheetDrag,
        onTap: () {
          if (_sheet.value > 0) _settleSheet(false);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            NextCard(
              model: c.model,
              now: c.now,
              mode: SkyMode.full,
              clock: clock,
              countdownWeight: c.countdownWeight,
              reveal: _sheet,
            ),
            Column(
              children: [
                header,
                Expanded(
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FadeTransition(
                              opacity: fadeOut,
                              child: DateRow(controller: c, onSky: true),
                            ),
                            const Spacer(),
                            FadeTransition(
                              opacity: fadeOut,
                              child: SwipeHint(onTap: () => _settleSheet(true), clock: clock),
                            ),
                          ],
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
                                  child: SkyTimesSheet(key: _sheetKey, controller: c),
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
                _Tabs(controller: c, onSky: true),
              ],
            ),
          ],
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

/// The two tabs at the bottom of the phone screen.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.controller, required this.onSky});

  final AppController controller;
  final bool onSky;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottom),
      decoration: BoxDecoration(
        color: onSky ? const Color(0x40000000) : c.bg.withValues(alpha: .94),
        border: Border(top: BorderSide(color: onSky ? const Color(0x24FFFFFF) : c.line)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 368),
          child: Row(
            children: [
              Expanded(
                child: _Tab(
                  label: 'Sot',
                  icon: VIcon.tabToday,
                  selected: controller.view == HomeView.today,
                  onSky: onSky,
                  onTap: () => controller.setView(HomeView.today),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Tab(
                  label: 'Muaji',
                  icon: VIcon.tabMonth,
                  selected: controller.view == HomeView.month,
                  onSky: onSky,
                  onTap: () => controller.setView(HomeView.month),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSky,
    required this.onTap,
  });

  final String label;
  final VIcon icon;
  final bool selected;
  final bool onSky;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = onSky ? (selected ? const Color(0xFFFFFFFF) : const Color(0xB8FFFFFF)) : (selected ? c.accent : c.muted);
    final bg = selected ? (onSky ? const Color(0x2BFFFFFF) : c.accentSoft) : Colors.transparent;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgIcon(icon, size: 20, color: fg),
              const SizedBox(width: 8),
              Text(label, style: vt(15, 750, color: fg, height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}
