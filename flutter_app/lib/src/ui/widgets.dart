import 'package:flutter/material.dart';

import '../logic/cities.dart';
import 'colors.dart';
import 'glass.dart';
import 'svg_icon.dart';
import 'text.dart';

const Color _skyFill = Color(0x21FFFFFF);
const Color _skyBorder = Color(0x3DFFFFFF);
const Color _white = Color(0xFFFFFFFF);

/// Makes a widget tappable with an accessible name.
class Tap extends StatelessWidget {
  const Tap({super.key, required this.onTap, required this.label, required this.child, this.button = true});

  final VoidCallback onTap;
  final String label;
  final Widget child;
  final bool button;

  @override
  Widget build(BuildContext context) => Semantics(
    button: button,
    label: label,
    excludeSemantics: true,
    onTap: onTap,
    child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
  );
}

/// The 40px round button of the header (settings, close).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.label, required this.onTap, this.onSky = false});

  final VIcon icon;
  final String label;
  final VoidCallback onTap;
  final bool onSky;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final circle = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onSky ? _skyFill : c.surface,
        border: Border.all(color: onSky ? _skyBorder : c.line),
      ),
      child: SvgIcon(icon, size: 19, color: onSky ? _white : c.ink),
    );
    return Tap(
      onTap: onTap,
      label: label,
      child: onSky
          ? ClipOval(
              child: Glass(radius: 999, fill: Colors.transparent, border: Colors.transparent, blur: 14, child: circle),
            )
          : circle,
    );
  }
}

/// The 40px arrows for the previous / next day or month.
class StepButton extends StatelessWidget {
  const StepButton({super.key, required this.next, required this.label, required this.onTap, this.onSky = false});

  final bool next;
  final String label;
  final VoidCallback onTap;
  final bool onSky;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tap(
      onTap: onTap,
      label: label,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: SvgIcon(
            next ? VIcon.stepNext : VIcon.stepPrev,
            size: 18,
            color: onSky ? const Color(0xD1FFFFFF) : c.muted,
          ),
        ),
      ),
    );
  }
}

/// A pill-shaped button: the day's "back to today", the tips toggle, "hide the prayer times".
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.onSky = false,
    this.fontSize = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    this.expand = false,
    this.semanticsLabel,
  });

  final String label;
  final VoidCallback onTap;
  final VIcon? icon;
  final bool onSky;
  final double fontSize;
  final EdgeInsets padding;
  final bool expand;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = onSky ? _white : c.accent;
    Widget row = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[SvgIcon(icon!, size: 19, color: fg), const SizedBox(width: 8)],
        Flexible(
          child: Text(
            label,
            style: vt(fontSize, 750, color: fg, height: 1.5),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: onSky ? _skyFill : c.surface,
        border: Border.all(color: onSky ? _skyBorder : c.line),
      ),
      child: row,
    );
    return Tap(
      onTap: onTap,
      label: semanticsLabel ?? label,
      child: onSky
          ? Glass(radius: 999, fill: Colors.transparent, border: Colors.transparent, blur: 14, child: box)
          : box,
    );
  }
}

final String _widestCity = cities.reduce((a, b) => a.name.length >= b.name.length ? a : b).name;

/// The city picker: a pill that opens a list of the cities.
class CityPicker extends StatelessWidget {
  const CityPicker({super.key, required this.city, required this.onSelected, this.onSky = false});

  final City city;
  final ValueChanged<City> onSelected;
  final bool onSky;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = onSky ? _white : c.ink;
    final pill = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .52),
      padding: const EdgeInsets.fromLTRB(16, 8, 36, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: onSky ? _skyFill : c.surface,
        border: Border.all(color: onSky ? _skyBorder : c.line),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // the pill is as wide as the longest city, so it does not change size when the city does
          Opacity(
            opacity: 0,
            child: Text(_widestCity, maxLines: 1, overflow: TextOverflow.ellipsis, style: vt(15, 750, height: 1.5)),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Text(
              city.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: vt(15, 750, color: fg, height: 1.5),
            ),
          ),
          Positioned(
            right: -22,
            top: 0,
            bottom: 0,
            child: Center(child: SvgIcon(VIcon.chevDown, size: 14, color: onSky ? const Color(0xCCFFFFFF) : c.muted)),
          ),
        ],
      ),
    );
    return Semantics(
      label: 'Qyteti: ${city.name}',
      button: true,
      excludeSemantics: true,
      child: PopupMenuButton<City>(
        tooltip: 'Qyteti',
        position: PopupMenuPosition.under,
        offset: const Offset(0, 6),
        color: c.surface,
        elevation: 6,
        constraints: const BoxConstraints(minWidth: 190),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.line),
        ),
        onSelected: onSelected,
        itemBuilder: (context) => [
          for (final item in cities)
            PopupMenuItem<City>(
              value: item,
              height: 44,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: vt(
                        15.5,
                        item.id == city.id ? 800 : 650,
                        color: item.id == city.id ? c.accent : c.ink,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (item.id == city.id) SvgIcon(VIcon.check, size: 18, color: c.accent),
                ],
              ),
            ),
        ],
        child: onSky
            ? Glass(radius: 999, fill: Colors.transparent, border: Colors.transparent, blur: 14, child: pill)
            : pill,
      ),
    );
  }
}

/// The app's name with its crescent.
class Brand extends StatelessWidget {
  const Brand({super.key, this.onSky = false});

  final bool onSky;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgIcon(VIcon.brand, size: 22, color: onSky ? _white : c.accent),
        const SizedBox(width: 8),
        Text(
          'Vaktet',
          style: vt(
            17,
            850,
            color: onSky ? _white : c.ink,
            ls: -.01,
            height: 1.5,
            shadows: onSky ? const [Shadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 1))] : null,
          ),
        ),
      ],
    );
  }
}

// ---------- Motion ----------

/// How long the show/hide animations take.
const Duration kMotion = Duration(milliseconds: 420);

/// [kMotion], or nothing when the phone asks for less motion.
Duration motion(BuildContext context) => MediaQuery.disableAnimationsOf(context) ? Duration.zero : kMotion;

/// Shows or hides [child]: its height slides open (or closed) from the top while it fades.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: motion(context),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: const Interval(.25, 1)),
        child: SizeTransition(sizeFactor: animation, alignment: Alignment.topCenter, child: child),
      ),
      layoutBuilder: (current, previous) =>
          Stack(alignment: Alignment.topCenter, fit: StackFit.passthrough, children: [...previous, ?current]),
      child: visible
          ? KeyedSubtree(key: const ValueKey(true), child: child)
          : const SizedBox(key: ValueKey(false), width: double.infinity),
    );
  }
}
