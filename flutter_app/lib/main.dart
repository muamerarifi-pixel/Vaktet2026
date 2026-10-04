import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/state/app_controller.dart';

/// For testing only: `--dart-define=VAKTET_NOW=2026-10-03T16:38:00Z` starts the app's clock at that instant.
int Function()? _testClock() {
  const start = String.fromEnvironment('VAKTET_NOW');
  if (start.isEmpty) return null;
  final from = DateTime.parse(start).millisecondsSinceEpoch;
  final watch = Stopwatch()..start();
  return () => from + watch.elapsedMilliseconds;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the status and navigation bars (the sky runs to the edges).
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();
  runApp(
    VaktetApp(
      controller: AppController(prefs: prefs, clock: _testClock()),
    ),
  );
}
