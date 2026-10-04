import 'package:flutter/material.dart';

import '../logic/prayer.dart';

/// Page colours (the web app's CSS variables), light and dark.
@immutable
class VaktetColors extends ThemeExtension<VaktetColors> {
  const VaktetColors({
    required this.dark,
    required this.bg,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.line,
    required this.accent,
    required this.accentInk,
    required this.accentSoft,
    required this.tipM,
    required this.tipMSoft,
  });

  final bool dark;
  final Color bg;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color faint;
  final Color line;
  final Color accent;
  final Color accentInk;
  final Color accentSoft;
  final Color tipM;
  final Color tipMSoft;

  static const light = VaktetColors(
    dark: false,
    bg: Color(0xFFEEF1EE),
    surface: Color(0xFFF8FAF8),
    ink: Color(0xFF14201C),
    muted: Color(0xFF5B6A64),
    faint: Color(0xFF8A9690),
    line: Color(0xFFD8DFDB),
    accent: Color(0xFF1D5E50),
    accentInk: Color(0xFFF4F8F6),
    accentSoft: Color(0xFFDCE9E4),
    tipM: Color(0xFF7A5A12),
    tipMSoft: Color(0xFFF3E9D2),
  );

  static const darkTheme = VaktetColors(
    dark: true,
    bg: Color(0xFF000000),
    surface: Color(0xFF111112),
    ink: Color(0xFFEDEDEE),
    muted: Color(0xFF9C9CA1),
    faint: Color(0xFF6D6D72),
    line: Color(0xFF232325),
    accent: Color(0xFF86CDB7),
    accentInk: Color(0xFF000000),
    accentSoft: Color(0xFF1C1C1E),
    tipM: Color(0xFFE6C77F),
    tipMSoft: Color(0xFF262012),
  );

  @override
  VaktetColors copyWith() => this;

  @override
  VaktetColors lerp(ThemeExtension<VaktetColors>? other, double t) => t < 0.5 ? this : (other as VaktetColors? ?? this);
}

extension VaktetColorsContext on BuildContext {
  VaktetColors get colors => Theme.of(this).extension<VaktetColors>()!;
}

/// One sky per prayer time (the web app's `body[data-phase]` variables).
class SkyPalette {
  const SkyPalette({
    required this.colors,
    required this.stops,
    required this.glow,
    required this.hazeA,
    required this.hazeB,
    required this.sun,
    required this.stars,
    required this.hill,
  });

  final List<Color> colors;
  final List<double> stops;

  /// Colour of the soft wash behind the page and the glow around the card.
  final Color glow;
  final Color hazeA;
  final Color hazeB;

  /// Colour of the sun and its glow.
  final Color sun;

  /// How visible the stars are, 0–1.
  final double stars;
  final Color hill;
}

const Map<SkyPhase, SkyPalette> skyPalettes = {
  SkyPhase.night: SkyPalette(
    colors: [Color(0xFF060A1C), Color(0xFF11173A), Color(0xFF232A5E)],
    stops: [0, .48, 1],
    glow: Color(0xFF3A3F96),
    hazeA: Color.fromRGBO(118, 92, 214, .42),
    hazeB: Color.fromRGBO(36, 80, 176, .42),
    sun: Color.fromRGBO(255, 236, 196, 1),
    stars: 1,
    hill: Color.fromRGBO(2, 4, 16, .62),
  ),
  SkyPhase.dawn: SkyPalette(
    colors: [Color(0xFF121844), Color(0xFF3E3A82), Color(0xFFB5687E), Color(0xFFEC9C78)],
    stops: [0, .42, .8, 1],
    glow: Color(0xFFB4698C),
    hazeA: Color.fromRGBO(255, 152, 140, .5),
    hazeB: Color.fromRGBO(116, 88, 206, .42),
    sun: Color.fromRGBO(255, 196, 156, 1),
    stars: .5,
    hill: Color.fromRGBO(28, 14, 44, .55),
  ),
  SkyPhase.morning: SkyPalette(
    colors: [Color(0xFF154F96), Color(0xFF2E78C0), Color(0xFFD7A77E)],
    stops: [0, .52, 1],
    glow: Color(0xFF3F86CC),
    hazeA: Color.fromRGBO(255, 214, 160, .5),
    hazeB: Color.fromRGBO(120, 190, 255, .45),
    sun: Color.fromRGBO(255, 242, 206, 1),
    stars: 0,
    hill: Color.fromRGBO(10, 36, 74, .45),
  ),
  SkyPhase.noon: SkyPalette(
    colors: [Color(0xFF0B3F7E), Color(0xFF1C64AC), Color(0xFF4E95D2)],
    stops: [0, .52, 1],
    glow: Color(0xFF2A78C4),
    hazeA: Color.fromRGBO(176, 222, 255, .42),
    hazeB: Color.fromRGBO(36, 112, 204, .5),
    sun: Color.fromRGBO(255, 251, 230, 1),
    stars: 0,
    hill: Color.fromRGBO(6, 30, 66, .48),
  ),
  SkyPhase.afternoon: SkyPalette(
    colors: [Color(0xFF1A3560), Color(0xFF7E4F5C), Color(0xFFD0864B)],
    stops: [0, .54, 1],
    glow: Color(0xFFCC8048),
    hazeA: Color.fromRGBO(255, 186, 104, .5),
    hazeB: Color.fromRGBO(150, 84, 128, .42),
    sun: Color.fromRGBO(255, 206, 128, 1),
    stars: 0,
    hill: Color.fromRGBO(40, 18, 18, .5),
  ),
  SkyPhase.dusk: SkyPalette(
    colors: [Color(0xFF0F1032), Color(0xFF432152), Color(0xFFA6434F), Color(0xFFDC7452)],
    stops: [0, .48, .84, 1],
    glow: Color(0xFFA8456A),
    hazeA: Color.fromRGBO(255, 118, 104, .45),
    hazeB: Color.fromRGBO(108, 58, 172, .45),
    sun: Color.fromRGBO(255, 206, 128, 1),
    stars: .65,
    hill: Color.fromRGBO(16, 6, 22, .6),
  ),
};

/// Top edge of each sky (what the phone's status bar takes when the card fills the screen).
Color skyTop(SkyPhase p) => skyPalettes[p]!.colors.first;
