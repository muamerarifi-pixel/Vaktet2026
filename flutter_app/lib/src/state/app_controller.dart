import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/cities.dart';
import '../logic/day.dart';
import '../logic/prayer.dart';

enum ThemeChoice { auto, light, dark }

enum HomeView { today, month }

/// The font of the whole app. All four are bundled (variable fonts, subset to Latin), so they work offline.
enum FontChoice {
  figtree('Figtree', 'Moderne'),
  nunito('Nunito', 'E butë'),
  lora('Lora', 'Klasike'),
  mono('JetBrainsMono', 'Digjitale');

  const FontChoice(this.family, this.label);

  /// The family name in pubspec.yaml.
  final String family;
  final String label;
}

/// What the app shell rebuilds from: the theme and the text look (not every tick).
typedef Look = ({ThemeChoice theme, FontChoice font, double fontScale});

/// Everything the screens show: the settings (kept on the phone), the selected day, and the ticking clock.
class AppController extends ChangeNotifier {
  AppController({required SharedPreferences prefs, int Function()? clock})
    : _prefs = prefs,
      _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch) {
    city = cityById(prefs.getString(_kCity));
    theme = ThemeChoice.values.firstWhere((t) => t.name == prefs.getString(_kTheme), orElse: () => ThemeChoice.auto);
    font = FontChoice.values.firstWhere((f) => f.name == prefs.getString(_kFont), orElse: () => FontChoice.figtree);
    final scale = prefs.getDouble(_kFontScale) ?? 1.0;
    fontScale = fontScales.contains(scale) ? scale : 1.0;
    final weight = prefs.getInt(_kCountWeight) ?? 900;
    countdownWeight = countdownWeights.contains(weight) ? weight : 900;
    lookNotifier = ValueNotifier<Look>(_look);
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
  static const _kFont = 'font';
  static const _kFontScale = 'fontScale';
  static const _kCountWeight = 'countdownWeight';

  static const List<int> alarmChoices = [15, 30, 45, 60];

  /// Text size, on top of the phone's own setting.
  static const List<double> fontScales = [.9, 1.0, 1.12, 1.25];

  /// Thickness of the big countdown digits.
  static const List<int> countdownWeights = [300, 500, 700, 900];

  final SharedPreferences _prefs;
  final int Function() _clock;
  Timer? _timer;

  late City city;
  late ThemeChoice theme;

  late FontChoice font;
  late double fontScale;
  late int countdownWeight;

  /// Changes only when the theme or the text look does (the app rebuilds from this, not from every tick).
  late final ValueNotifier<Look> lookNotifier;

  Look get _look => (theme: theme, font: font, fontScale: fontScale);
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
    lookNotifier.dispose();
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
    lookNotifier.value = _look;
    _prefs.setString(_kTheme, t.name);
    _changed();
  }

  void setFont(FontChoice f) {
    font = f;
    lookNotifier.value = _look;
    _prefs.setString(_kFont, f.name);
    _changed();
  }

  void setFontScale(double v) {
    fontScale = v;
    lookNotifier.value = _look;
    _prefs.setDouble(_kFontScale, v);
    _changed();
  }

  void setCountdownWeight(int w) {
    countdownWeight = w;
    _prefs.setInt(_kCountWeight, w);
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
