import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import 'colors.dart';
import 'svg_icon.dart';
import 'text.dart';
import 'widgets.dart';

Future<void> showSettings(BuildContext context, AppController controller) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x73080E0C),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => _Sheet(controller: controller),
        ),
      ),
    ),
  );
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.dark ? .5 : .06),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.dark ? .8 : .14),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -12,
          ),
        ],
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
                  child: Text('Cilësimet', style: vt(19, 850, color: colors.ink, height: 1.5)),
                ),
                RoundIconButton(icon: VIcon.close, label: 'Mbyll', onTap: () => Navigator.of(context).pop()),
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
            Container(
              margin: const EdgeInsets.only(top: 18),
              padding: const EdgeInsets.only(top: 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.line)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kohët janë nga Takvimi zyrtar i Bashkësisë Islame të Kosovës. Qytetet që Takvimi i shënon me dallim (Prishtina, Ferizaj, Gjilani, Podujeva, Vushtrria −1 min, Sharri +2 min) e kanë të llogaritur dallimin; qytetet e tjera përdorin kohët bazë.',
                    style: vt(13.5, 500, color: colors.muted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aplikacioni punon pa internet dhe e llogarit vetë kalimin në orën verore e dimërore, prandaj kohët mbeten të sakta edhe në vitet në vijim.',
                    style: vt(13.5, 500, color: colors.muted),
                  ),
                ],
              ),
            ),
          ],
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
          Text(title, style: vt(15, 800, color: colors.ink, height: 1.5)),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!, style: vt(13.5, 500, color: colors.muted)),
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
  const Segmented({super.key, required this.options, required this.value, required this.onChanged});

  final List<(String, T)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: c.bg,
        border: Border.all(color: c.line),
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
                onTap: () => onChanged(options[i].$2),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(options[i].$2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: options[i].$2 == value ? c.surface : null,
                      boxShadow: options[i].$2 == value
                          ? const [BoxShadow(color: Color(0x1F000000), blurRadius: 3, offset: Offset(0, 1))]
                          : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        options[i].$1,
                        softWrap: false,
                        style: vt(14, 720, color: options[i].$2 == value ? c.ink : c.muted, height: 1.5),
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
