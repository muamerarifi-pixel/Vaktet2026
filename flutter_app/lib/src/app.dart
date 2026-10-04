import 'package:flutter/material.dart';

import 'state/app_controller.dart';
import 'ui/colors.dart';
import 'ui/home.dart';

class VaktetApp extends StatelessWidget {
  const VaktetApp({super.key, required this.controller});

  final AppController controller;

  ThemeData _theme(VaktetColors c, FontChoice font) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: c.dark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.accent,
        brightness: c.dark ? Brightness.dark : Brightness.light,
      ).copyWith(surface: c.surface, onSurface: c.ink, primary: c.accent),
      fontFamily: font.family,
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
    return ValueListenableBuilder<Look>(
      valueListenable: controller.lookNotifier,
      builder: (context, look, _) => MaterialApp(
        title: 'Vaktet',
        debugShowCheckedModeBanner: false,
        theme: _theme(VaktetColors.light, look.font),
        darkTheme: _theme(VaktetColors.darkTheme, look.font),
        themeMode: switch (look.theme) {
          ThemeChoice.auto => ThemeMode.system,
          ThemeChoice.light => ThemeMode.light,
          ThemeChoice.dark => ThemeMode.dark,
        },
        // the phone's text size (within limits), times the size picked in the settings
        builder: (context, child) {
          final media = MediaQuery.of(context);
          final phone = media.textScaler.clamp(minScaleFactor: .85, maxScaleFactor: 1.3).scale(100) / 100;
          return MediaQuery(
            data: media.copyWith(textScaler: TextScaler.linear(phone * look.fontScale)),
            child: child!,
          );
        },
        home: HomePage(controller: controller),
      ),
    );
  }
}
