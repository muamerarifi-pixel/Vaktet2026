import 'package:flutter/material.dart';

import 'state/app_controller.dart';
import 'ui/colors.dart';
import 'ui/home.dart';
import 'ui/text.dart';

class VaktetApp extends StatelessWidget {
  const VaktetApp({super.key, required this.controller});

  final AppController controller;

  ThemeData _theme(VaktetColors c) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: c.dark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.accent,
        brightness: c.dark ? Brightness.dark : Brightness.light,
      ).copyWith(surface: c.surface, onSurface: c.ink, primary: c.accent),
      fontFamily: kFont,
      scaffoldBackgroundColor: c.bg,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      extensions: [c],
    );
    return base.copyWith(
      popupMenuTheme: PopupMenuThemeData(color: c.surface, surfaceTintColor: Colors.transparent),
      dialogTheme: DialogThemeData(backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeChoice>(
      valueListenable: controller.themeNotifier,
      builder: (context, choice, _) => MaterialApp(
        title: 'Vaktet',
        debugShowCheckedModeBanner: false,
        theme: _theme(VaktetColors.light),
        darkTheme: _theme(VaktetColors.darkTheme),
        themeMode: switch (choice) {
          ThemeChoice.auto => ThemeMode.system,
          ThemeChoice.light => ThemeMode.light,
          ThemeChoice.dark => ThemeMode.dark,
        },
        builder: (context, child) =>
            MediaQuery.withClampedTextScaling(minScaleFactor: .85, maxScaleFactor: 1.3, child: child!),
        home: HomePage(controller: controller),
      ),
    );
  }
}
