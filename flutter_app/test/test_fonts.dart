import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the real Figtree font, so text in tests has the same size as on a phone (the default test font is wide).
Future<void> loadAppFonts() async {
  final bytes = await File('assets/fonts/Figtree.ttf').readAsBytes();
  final loader = FontLoader('Figtree')..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}
