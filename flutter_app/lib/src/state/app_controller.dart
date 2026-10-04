import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/cities.dart';
import '../logic/day.dart';
import '../logic/prayer.dart';

enum ThemeChoice { auto, light, dark }

enum HomeView { today, month }

/// Everything the screens show: the settings (kept on the phone), the selected day, and the ticking clock.
class AppController extends ChangeNotifier {
  AppController({required SharedPreferences prefs, int Function()? clock})
    : _prefs = prefs,
      _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch) {
    city = cityById(prefs.getString(_kCity));
    theme = ThemeChoice.values.firstWhere((t) => t.name == prefs.getString(_kTheme), orElse: () => ThemeChoice.auto);
    themeNotifier = ValueNotifier<ThemeChoice>(theme);
    final adj = prefs.getInt(_kHijri) ?? 0;
    hijriAdj = adj.clamp(-2, 2);
    final alarm = prefs.getInt(_kAlarm) ?? 30;
    alarmOffset = alarmChoices.contains(alarm) ? alarm : 30;
    focus = prefs.getBool(_kFocus) ?? false;
    tipsOn = prefs.getBool(_kTips) ?? true;
    now = _clock();
    today = kosovoToday(now);
    selected = today;
    cursorY = today.y;
    cursorM = today.m;
    _recompute();
  }

  static const _kCity = 'city';
  static const _kTheme = 'theme';
  static const _kHijri = 'hijri';
  static const _kAlarm = 'alarm';
  static const _kFocus = 'focus';
  static const _kTips = 'tips';

  static const List<int> alarmChoices = [15, 30, 45, 60];

  final SharedPreferences _prefs;
  final int Function() _clock;
  Timer? _timer;

  late City city;
  late ThemeChoice theme;

  /// Changes only when the theme does (the app rebuilds from this, not from every tick).
  late final ValueNotifier<ThemeChoice> themeNotifier;
  late int hijriAdj;
  late int alarmOffset;

  /// "Hide the prayer times" — only the card (and the tips) is left.
  late bool focus;
  late bool tipsOn;

  HomeView view = HomeView.today;

  /// Epoch milliseconds of the last tick.
  late int now;
  late Day today;
  late Day selected;

  /// The month shown in the Month tab.
  late int cursorY;
  late int cursorM;

  late TodayModel model;

  bool get isToday => selected == today;

  /// The prayer list is hidden (only possible while looking at today).
  bool get focusOn => focus && isToday;

  void _recompute() {
    model = computeToday(now: now, today: today, selected: selected, city: city, alarmOffset: alarmOffset);
  }

  // ---------- Clock ----------

  /// Starts ticking on whole seconds.
  void start() {
    _timer?.cancel();
    tick();
    _schedule();
  }

  void _schedule() {
    final msIntoSecond = _clock() % 1000;
    _timer = Timer(Duration(milliseconds: 1000 - msIntoSecond + 15), () {
      tick();
      _schedule();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void tick() {
    now = _clock();
    final t = kosovoToday(now);
    if (t != today) {
      final wasToday = selected == today;
      today = t;
      if (wasToday) {
        selected = t;
        cursorY = t.y;
        cursorM = t.m;
      }
    }
    _recompute();
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    themeNotifier.dispose();
    super.dispose();
  }

  // ---------- Actions ----------

  void _changed() {
    _recompute();
    notifyListeners();
  }

  void setCity(City c) {
    city = c;
    _prefs.setString(_kCity, c.id);
    _changed();
  }

  void setTheme(ThemeChoice t) {
    theme = t;
    themeNotifier.value = t;
    _prefs.setString(_kTheme, t.name);
    _changed();
  }

  void setHijriAdj(int v) {
    hijriAdj = v.clamp(-2, 2);
    _prefs.setInt(_kHijri, hijriAdj);
    _changed();
  }

  void setAlarmOffset(int v) {
    alarmOffset = v;
    _prefs.setInt(_kAlarm, v);
    _changed();
  }

  void toggleFocus() {
    focus = !focus;
    _prefs.setBool(_kFocus, focus);
    _changed();
  }

  void toggleTips() {
    tipsOn = !tipsOn;
    _prefs.setBool(_kTips, tipsOn);
    _changed();
  }

  void setView(HomeView v) {
    view = v;
    _changed();
  }

  /// Show a day (and the month it is in).
  void select(Day day) {
    selected = day;
    cursorY = day.y;
    cursorM = day.m;
    _changed();
  }

  void stepDay(int n) => select(selected.addDays(n));

  void selectToday() => select(today);

  void stepMonth(int n) {
    final index = cursorY * 12 + (cursorM - 1) + n;
    cursorY = index ~/ 12;
    cursorM = index % 12 + 1;
    notifyListeners();
  }
}
