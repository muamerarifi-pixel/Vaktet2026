import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the real fonts, so text in tests has the same size as on a phone (the default test font is wide).
Future<void> loadAppFonts() async {
  for (final (family, file) in const [
    ('Figtree', 'Figtree.ttf'),
    ('Manrope', 'Manrope-Light.ttf'),
    ('Nunito', 'Nunito.ttf'),
    ('Lora', 'Lora.ttf'),
    ('JetBrainsMono', 'JetBrainsMono.ttf'),
  ]) {
    final bytes = await File('assets/fonts/$file').readAsBytes();
    final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
  for (final (family, file) in const [
    ('VaktetManrope', 'Manrope'),
    ('VaktetCormorant', 'CormorantGaramond'),
    ('VaktetPlayfair', 'PlayfairDisplay'),
    ('VaktetCinzel', 'Cinzel'),
    ('VaktetOutfit', 'Outfit'),
    ('VaktetUnbounded', 'Unbounded'),
  ]) {
    final bytes = await File('assets/fonts/countdown/$file.ttf').readAsBytes();
    final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}
