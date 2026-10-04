import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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
  const HomePage({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final SkyClock _sky = SkyClock();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.start();
    _sky.start();
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
    super.dispose();
  }

  /// Stop ticking while the app is out of sight, and catch up as soon as it comes back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.start();
      _sky.start();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      widget.controller.stop();
      _sky.stop();
    }
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
    final clock = MediaQuery.disableAnimationsOf(context) ? null : _sky;
    final fullSky = !wide && c.view == HomeView.today && c.focusOn && !c.tipsOn;

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
    if (wide) {
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
      body = Stack(
        fit: StackFit.expand,
        children: [
          NextCard(model: model, now: c.now, mode: SkyMode.full, clock: clock, countdownWeight: c.countdownWeight),
          Column(
            children: [
              header,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DateRow(controller: c, onSky: true),
                      const Spacer(),
                      BelowCard(controller: c, onSky: true),
                    ],
                  ),
                ),
              ),
              _Tabs(controller: c, onSky: true),
            ],
          ),
        ],
      );
    } else {
      final today = c.view == HomeView.today;
      body = Column(
        children: [
          header,
          Expanded(
            child: SingleChildScrollView(
              key: ValueKey(c.view), // a fresh scroll position on each tab
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
        // going to (or leaving) the full-screen sky: the new page fades in while it grows into place
        body: AnimatedSwitcher(
          duration: motion(context),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: fullSky ? .94 : 1.04, end: 1.0).animate(animation),
              child: child,
            ),
          ),
          child: Stack(
            key: ValueKey(fullSky),
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
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottom),
          decoration: BoxDecoration(
            color: onSky ? const Color(0x33000000) : c.bg.withValues(alpha: .88),
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
        child: Container(
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
