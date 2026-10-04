import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the real fonts, so text in tests has the same size as on a phone (the default test font is wide).
Future<void> loadAppFonts() async {
  for (final family in ['Figtree', 'Nunito', 'Lora', 'JetBrainsMono']) {
    final bytes = await File('assets/fonts/$family.ttf').readAsBytes();
    final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}
