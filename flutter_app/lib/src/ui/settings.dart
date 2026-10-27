import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_controller.dart';
import 'colors.dart';
import 'svg_icon.dart';
import 'text.dart';
import 'widgets.dart';

Future<void> showSettings(BuildContext context, AppController controller) {
  HapticFeedback.lightImpact();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x28000000),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, animation, secondaryAnimation) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        // only the settings change what it shows, not the ticking clock
        child: ListenableBuilder(
          listenable: controller.settingsVersion,
          builder: (context, _) => _Sheet(controller: controller),
        ),
      ),
    ),
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curve,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(curve),
          child: child,
        ),
      );
    },
  );
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final colors = context.colors;
    final isDark = colors.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? .30 : .12),
            blurRadius: 28,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? .18 : .05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [
                        Color(0x38FFFFFF),
                        Color(0x2418221D),
                        Color(0x2E0E1713),
                      ]
                    : const [
                        Color(0x80FFFFFF),
                        Color(0x55FFFFFF),
                        Color(0x3EFFFFFF),
                      ],
                stops: const [0.0, 0.45, 1.0],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? const Color(0x50FFFFFF) : const Color(0x85FFFFFF),
                width: 1.2,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Semantics(
                        header: true,
                        child: Text('Cilësimet', style: vt(19, 850, color: isDark ? Colors.white : colors.ink, height: 1.5)),
                      ),
                      RoundIconButton(icon: VIcon.close, label: 'Mbyll', onTap: () => Navigator.of(context).pop(), onSky: true),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _Field(
              title: 'Pamja',
              child: Segmented<ThemeChoice>(
                options: const [
                  ('Automatike', ThemeChoice.auto),
                  ('E çelët', ThemeChoice.light),
                  ('E errët', ThemeChoice.dark),
                ],
                value: c.theme,
                onChanged: c.setTheme,
              ),
            ),
            _Field(
              title: 'Data hixhri',
              hint: 'Nëse data hixhri ndryshon nga ajo e shpallur nga BIK, korrigjojeni me ditë.',
              child: Segmented<int>(
                options: const [('−2', -2), ('−1', -1), ('0', 0), ('+1', 1), ('+2', 2)],
                value: c.hijriAdj,
                onChanged: c.setHijriAdj,
              ),
            ),
            _Field(
              title: 'Alarmi për sabah',
              hint: 'Sa minuta para lindjes së diellit të sugjerohet alarmi.',
              child: Segmented<int>(
                options: [for (final m in AppController.alarmChoices) ('$m min', m)],
                value: c.alarmOffset,
                onChanged: c.setAlarmOffset,
              ),
            ),
            _Field(
              title: 'Stili i shkronjave',
              child: Segmented<FontChoice>(
                options: [for (final f in FontChoice.values) (f.label, f)],
                value: c.font,
                onChanged: c.setFont,
                fontOf: (f) => f.family,
              ),
            ),
            _Field(
              title: 'Madhësia e shkronjave',
              child: Segmented<double>(
                options: const [('E vogël', .9), ('Normale', 1.0), ('E madhe', 1.12), ('Më e madhe', 1.25)],
                value: c.fontScale,
                onChanged: c.setFontScale,
              ),
            ),
            _Field(
              title: 'Shkronjat e kohës së mbetur',
              hint: 'Fytyra e shifrave të mëdha të numërimit.',
              child: _CountdownFonts(value: c.countdownFont, weight: c.countdownWeight, onChanged: c.setCountdownFont),
            ),
            _Field(
              title: 'Trashësia e kohës së mbetur',
              hint: 'Sa të trasha janë shifrat e mëdha të kohës deri te vakti tjetër.',
              child: Segmented<int>(
                options: const [('Hollë', 300), ('Normale', 500), ('E trashë', 700), ('Shumë', 900)],
                value: c.countdownWeight,
                onChanged: c.setCountdownWeight,
                weightOf: (w) => w.toDouble(),
              ),
            ),
            _Field(
              title: 'Madhësia e kohës së mbetur',
              hint: 'Sa të mëdha janë shifrat e kohës deri te vakti tjetër.',
              child: Segmented<double>(
                options: const [('80%', .8), ('100%', 1.0), ('115%', 1.15), ('130%', 1.3)],
                value: c.countdownSize,
                onChanged: c.setCountdownSize,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 2),
              child: Text('Veçoritë', style: vt(15, 800, color: isDark ? Colors.white : colors.ink, height: 1.5)),
            ),
            Text('Ndizni ose fikni çdo pjesë të aplikacionit.', style: vt(13.5, 500, color: isDark ? const Color(0xC0FFFFFF) : colors.muted)),
            const SizedBox(height: 6),
            for (final f in Feature.values)
              _Switch(title: f.title, hint: f.hint, value: c.on(f), onChanged: (v) => c.setFeature(f, v)),
            Container(
              margin: const EdgeInsets.only(top: 18),
              padding: const EdgeInsets.only(top: 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: isDark ? const Color(0x35FFFFFF) : colors.line)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kohët janë nga Takvimi zyrtar i Bashkësisë Islame të Kosovës. Qytetet që Takvimi i shënon me dallim (Prishtina, Ferizaj, Gjilani, Podujeva, Vushtrria −1 min, Sharri +2 min) e kanë të llogaritur dallimin; qytetet e tjera përdorin kohët bazë.',
                    style: vt(13.5, 500, color: isDark ? const Color(0xC0FFFFFF) : colors.muted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aplikacioni punon pa internet dhe e llogarit vetë kalimin në orën verore e dimërore, prandaj kohët mbeten të sakta edhe në vitet në vijim.',
                    style: vt(13.5, 500, color: isDark ? const Color(0xC0FFFFFF) : colors.muted),
                  ),
                ],
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

/// The countdown's fonts, each shown as a little countdown in its own face.
class _CountdownFonts extends StatelessWidget {
  const _CountdownFonts({required this.value, required this.weight, required this.onChanged});

  final CountdownFont value;
  final int weight;
  final ValueChanged<CountdownFont> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget tile(CountdownFont f) {
      final on = f == value;
      return Semantics(
        inMutuallyExclusiveGroup: true,
        checked: on,
        label: f.label,
        excludeSemantics: true,
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(f);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(f);
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: on
                  ? (c.dark ? const Color(0x48FFFFFF) : const Color(0xB0FFFFFF))
                  : (c.dark ? const Color(0x1E000000) : const Color(0x2AFFFFFF)),
              border: Border.all(
                color: on ? c.accent : (c.dark ? const Color(0x28FFFFFF) : const Color(0x25000000)),
                width: on ? 1.6 : 1,
              ),
              boxShadow: on
                  ? [
                      BoxShadow(
                        color: c.accent.withValues(alpha: 0.18),
                        blurRadius: 6,
                        offset: const Offset(0, 1.5),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '05:42',
                    softWrap: false,
                    style: vt(
                      24,
                      weight.toDouble(),
                      color: on ? (c.dark ? Colors.white : c.ink) : (c.dark ? const Color(0xCCFFFFFF) : c.muted),
                      height: 1.15,
                    ).copyWith(fontFamily: f.family, fontFeatures: const [FontFeature.liningFigures()]),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  f.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: vt(12, 700, color: on ? c.accent : (c.dark ? const Color(0x9EFFFFFF) : c.muted), height: 1.3),
                ),
              ],
            ),
          ),
        ),
      );
    }

    const perRow = 3;
    final fonts = CountdownFont.values;
    return Column(
      children: [
        for (var r = 0; r < fonts.length; r += perRow) ...[
          if (r > 0) const SizedBox(height: 6),
          Row(
            children: [
              for (var i = r; i < r + perRow; i++) ...[
                if (i > r) const SizedBox(width: 6),
                Expanded(child: i < fonts.length ? tile(fonts[i]) : const SizedBox()),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// A feature that can be switched on and off.
class _Switch extends StatelessWidget {
  const _Switch({required this.title, required this.hint, required this.value, required this.onChanged});

  final String title;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      toggled: value,
      label: title,
      excludeSemantics: true,
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: vt(14.5, 750, color: colors.dark ? Colors.white : colors.ink, height: 1.35)),
                    Text(hint, style: vt(12.5, 500, color: colors.dark ? const Color(0xB8FFFFFF) : colors.muted, height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _Toggle(on: value),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small switch in the app's colours.
class _Toggle extends StatelessWidget {
  const _Toggle({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = motion(context) == Duration.zero ? Duration.zero : const Duration(milliseconds: 180);
    return AnimatedContainer(
      duration: d,
      curve: Curves.easeOut,
      width: 44,
      height: 26,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: on ? c.accent : (c.dark ? const Color(0x35FFFFFF) : c.line)),
      child: AnimatedAlign(
        duration: d,
        curve: Curves.easeOut,
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? c.accentInk : c.surface,
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 2, offset: Offset(0, 1))],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.title, required this.child, this.hint});

  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: vt(15, 800, color: colors.dark ? Colors.white : colors.ink, height: 1.5)),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!, style: vt(13.5, 500, color: colors.dark ? const Color(0xC0FFFFFF) : colors.muted)),
            const SizedBox(height: 10),
          ] else
            const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// A pill-shaped choice of one of a few options.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.fontOf,
    this.weightOf,
  });

  final List<(String, T)> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// Shows each option in its own font / weight (a preview of the choice).
  final String Function(T)? fontOf;
  final double Function(T)? weightOf;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = c.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: isDark ? const Color(0x24000000) : const Color(0x1C000000),
        border: Border.all(color: isDark ? const Color(0x30FFFFFF) : const Color(0x22000000), width: 1),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Semantics(
                inMutuallyExclusiveGroup: true,
                checked: options[i].$2 == value,
                label: options[i].$1,
                excludeSemantics: true,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(options[i].$2);
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(options[i].$2);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: options[i].$2 == value
                          ? (isDark ? const Color(0x4EFFFFFF) : const Color(0xD8FFFFFF))
                          : null,
                      border: options[i].$2 == value
                          ? Border.all(
                              color: isDark ? const Color(0x65FFFFFF) : const Color(0x88FFFFFF),
                              width: 1,
                            )
                          : null,
                      boxShadow: options[i].$2 == value
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? .20 : .08),
                                blurRadius: 4,
                                offset: const Offset(0, 1.5),
                              ),
                            ]
                          : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        options[i].$1,
                        softWrap: false,
                        style: vt(
                          14,
                          weightOf?.call(options[i].$2) ?? 720,
                          color: options[i].$2 == value ? (isDark ? Colors.white : c.ink) : (isDark ? const Color(0xB8FFFFFF) : c.muted),
                          height: 1.5,
                        ).copyWith(fontFamily: fontOf?.call(options[i].$2)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
