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

/// The parts of the app that can be switched on and off in the settings: (title, hint, on by default).
enum Feature {
  fridayLook(
    'Pamja e xhumasë',
    'Të premteve koha e mbetur shkëlqen në ar, dhe natën e xhumasë qielli mbushet me yje.',
    true,
  ),
  landscape(
    'Malet dhe liqeni',
    'Male me borë sipas stinës dhe një liqen që i pasqyron. Nuk lëvizin, nuk harxhojnë bateri.',
    true,
  ),
  skyLife(
    'Qiell i gjallë',
    'Yjet vezullojnë, retë lundrojnë, kalojnë zogj e avionë. Fikeni për të kursyer baterinë.',
    true,
  ),
  hijri('Shfaq datën hixhri', 'Data hixhri nën datën e sotme dhe në muaj.', true),
  national('Ditët kombëtare të Kosovës', 'Festat zyrtare dhe ditët përkujtimore në ekranin kryesor.', true),
  islamic('Netët dhe ditët e mëdha islame', 'Kadri, Miraxhi, Berati, Bajramet, Ashura … në ekranin kryesor.', true),
  takvim('Shënimet e Takvimit të BIK', 'Hëna e re dhe e plotë, stinët, xhemret, ora verore …', true),
  homeAlarm('Alarmi për sabah në ekran', 'Pas jacisë e deri në imsak, alarmi shihet pa rrëshqitur lart.', true),
  nafile('Sugjerime për namaze nafile', 'Duha, Evvabini dhe Tehexhudi, me shkronja të vogla kur u vjen koha.', true),
  tips('Këshillat e ditës', 'Dy këshilla për çdo ditë, nën vaktet.', true),
  hints('Udhëzimi i rrëshqitjes', '„Rrëshqit lart për vaktet“ në fund të ekranit.', true),
  daySwipe('Rrëshqit majtas/djathtas për ditët', 'Me një rrëshqitje anash kalon te dita tjetër ose e mëparshme.', true),
  pulse('Drita kur hyn vakti', 'Një valë e butë drite kur vjen koha e namazit.', true),
  haptics('Dridhja e lehtë', 'Një dridhje e vogël kur ndryshon dita.', true);

  const Feature(this.title, this.hint, this.byDefault);

  final String title;
  final String hint;
  final bool byDefault;

  String get _key => 'f_$name';
}

/// The font of the big countdown. The four bundled faces carry only the digits and the colon, so they weigh
/// a few kilobytes each.
enum CountdownFont {
  text(null, 'Si teksti'),
  cormorant('VaktetCormorant', 'Elegante'),
  playfair('VaktetPlayfair', 'Fisnike'),
  cinzel('VaktetCinzel', 'Romake'),
  outfit('VaktetOutfit', 'E pastër'),
  unbounded('VaktetUnbounded', 'E gjerë');

  const CountdownFont(this.family, this.label);

  /// The family in pubspec.yaml; null for the font of the rest of the app.
  final String? family;
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
    countdownFont = CountdownFont.values.firstWhere(
      (f) => f.name == prefs.getString(_kCountFont),
      orElse: () => CountdownFont.text,
    );
    final weight = prefs.getInt(_kCountWeight) ?? 900;
    countdownWeight = countdownWeights.contains(weight) ? weight : 900;
    lookNotifier = ValueNotifier<Look>(_look);
    final adj = prefs.getInt(_kHijri) ?? 0;
    hijriAdj = adj.clamp(-2, 2);
    final alarm = prefs.getInt(_kAlarm) ?? 30;
    alarmOffset = alarmChoices.contains(alarm) ? alarm : 30;
    for (final f in Feature.values) {
      _features[f] = prefs.getBool(f._key) ?? f.byDefault;
    }
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
  static const _kFont = 'font';
  static const _kFontScale = 'fontScale';
  static const _kCountWeight = 'countdownWeight';
  static const _kCountFont = 'countdownFont';

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
  late CountdownFont countdownFont;

  /// Changes only when the theme or the text look does (the app rebuilds from this, not from every tick).
  late final ValueNotifier<Look> lookNotifier;

  Look get _look => (theme: theme, font: font, fontScale: fontScale);
  late int hijriAdj;
  late int alarmOffset;

  final Map<Feature, bool> _features = {};

  /// Whether a part of the app is switched on.
  bool on(Feature f) => _features[f] ?? f.byDefault;

  /// Bumped on every change of the settings (not on the ticks), for the screens that only show settings.
  final ValueNotifier<int> settingsVersion = ValueNotifier<int>(0);

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

  /// The moment shown: now, or — while another day is shown — the same time of day on that day, so its sky,
  /// sun, moon and season can be seen as they will be (or were) at this hour.
  int get viewNow =>
      now +
      (selected.epochDay - today.epochDay) * msPerDay +
      (kosovoOffsetForDay(today) - kosovoOffsetForDay(selected)) * msPerMinute;

  void _recompute() {
    final at = viewNow;
    model = computeToday(
      now: at,
      today: selected,
      selected: selected,
      city: city,
      alarmOffset: alarmOffset,
      hijriAdj: hijriAdj,
    );
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
    settingsVersion.dispose();
    super.dispose();
  }

  // ---------- Actions ----------

  void _changed() {
    _recompute();
    notifyListeners();
  }

  void _settingChanged() {
    settingsVersion.value++;
    _changed();
  }

  void setCity(City c) {
    city = c;
    _prefs.setString(_kCity, c.id);
    _settingChanged();
  }

  void setTheme(ThemeChoice t) {
    theme = t;
    lookNotifier.value = _look;
    _prefs.setString(_kTheme, t.name);
    _settingChanged();
  }

  void setFont(FontChoice f) {
    font = f;
    lookNotifier.value = _look;
    _prefs.setString(_kFont, f.name);
    _settingChanged();
  }

  void setFontScale(double v) {
    fontScale = v;
    lookNotifier.value = _look;
    _prefs.setDouble(_kFontScale, v);
    _settingChanged();
  }

  void setCountdownWeight(int w) {
    countdownWeight = w;
    _prefs.setInt(_kCountWeight, w);
    _settingChanged();
  }

  void setCountdownFont(CountdownFont f) {
    countdownFont = f;
    _prefs.setString(_kCountFont, f.name);
    _settingChanged();
  }

  void setHijriAdj(int v) {
    hijriAdj = v.clamp(-2, 2);
    _prefs.setInt(_kHijri, hijriAdj);
    _settingChanged();
  }

  void setAlarmOffset(int v) {
    alarmOffset = v;
    _prefs.setInt(_kAlarm, v);
    _settingChanged();
  }

  void setFeature(Feature f, bool value) {
    _features[f] = value;
    _prefs.setBool(f._key, value);
    _settingChanged();
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
