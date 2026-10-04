// Drives the real screens: changing the day, the city, the settings, hiding the prayer times.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaktet/src/app.dart';
import 'package:vaktet/src/state/app_controller.dart';

import 'test_fonts.dart';

/// Saturday 3 October 2026, 18:38 in Kosovo (16:38 UTC): the sky is at dusk and Jacia (19:52) is next.
final int _dusk = DateTime.utc(2026, 10, 3, 16, 38).millisecondsSinceEpoch;

Future<AppController> _open(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  int? at,
  Size size = const Size(390, 844),
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  final controller = AppController(prefs: store, clock: () => at ?? _dusk);
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(VaktetApp(controller: controller));
  await tester.pump(const Duration(milliseconds: 100));
  return controller;
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

Finder _label(String text) => find.bySemanticsLabel(text);

void main() {
  setUpAll(loadAppFonts);

  testWidgets('shows today: date, Hijri date, next prayer and countdown', (tester) async {
    final handle = tester.ensureSemantics();
    await _open(tester);
    expect(find.text('E shtunë, 3 tetor 2026'), findsOneWidget);
    expect(find.text('22 Rebiul Ahir 1448 h.'), findsOneWidget);
    expect(find.text('NAMAZI I ARDHSHËM'), findsOneWidget);
    expect(find.text('Jacia'), findsWidgets);
    expect(find.text('19:52'), findsWidgets);
    expect(find.textContaining('01:14:00', findRichText: true), findsOneWidget);
    expect(find.text('deri në fillim'), findsOneWidget);
    expect(find.text('Alarmi për sabah'), findsNothing); // not yet: Jacia has not passed
    expect(find.text('Kosovë'), findsOneWidget);
    handle.dispose();
    await _close(tester);
  });

  testWidgets('the countdown moves with the clock', (tester) async {
    var now = _dusk;
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(prefs: await SharedPreferences.getInstance(), clock: () => now);
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(VaktetApp(controller: controller));
    await tester.pump();
    expect(find.textContaining('01:14:00', findRichText: true), findsOneWidget);
    now += 61 * 1000;
    controller.tick();
    await tester.pump();
    expect(find.textContaining('01:12:59', findRichText: true), findsOneWidget);
    await _close(tester);
  });

  testWidgets('after Jacia the card shows tomorrow and the alarm suggestion appears', (tester) async {
    // 21:00 in Kosovo
    await _open(tester, at: DateTime.utc(2026, 10, 3, 19).millisecondsSinceEpoch);
    expect(find.text('NESËR'), findsOneWidget);
    expect(find.text('Imsaku'), findsWidgets);
    expect(find.text('Alarmi për sabah'), findsOneWidget);
    expect(find.textContaining('Nesër, 30 min para lindjes së diellit'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('a forbidden time turns the card red with a warning', (tester) async {
    // 06:31 in Kosovo, five minutes after sunrise
    await _open(tester, at: DateTime.utc(2026, 10, 3, 4, 31).millisecondsSinceEpoch);
    expect(find.text('KOHË E NDALUAR PËR NAMAZ'), findsOneWidget);
    expect(find.text('06:26 – 06:41'), findsOneWidget);
    expect(find.text('deri sa të kalojë'), findsOneWidget);
    expect(find.textContaining('Namazi i ardhshëm: Hyrja e drekës 12:28'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('stepping to another day shows its times and a way back to today', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await _open(tester);
    await tester.tap(_label('Dita tjetër'));
    await tester.pump();
    expect(find.text('E diel, 4 tetor 2026'), findsOneWidget);
    expect(find.text('Kthehu te sot'), findsOneWidget);
    expect(find.text('NAMAZI I ARDHSHËM'), findsNothing);
    expect(find.text('04:54'), findsOneWidget); // Imsaku on 4 October
    await tester.tap(find.text('Kthehu te sot'));
    await tester.pump();
    expect(c.isToday, isTrue);
    expect(find.text('E shtunë, 3 tetor 2026'), findsOneWidget);
    await tester.tap(_label('Dita e mëparshme'));
    await tester.pump();
    expect(find.text('E premte, 2 tetor 2026'), findsOneWidget);
    expect(find.text('Xhumaja'), findsOneWidget);
    handle.dispose();
    await _close(tester);
  });

  testWidgets('changing the city moves the times and is remembered', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await _open(tester);
    expect(find.text('04:53'), findsOneWidget);
    await tester.tap(find.text('Kosovë'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prishtinë').last);
    await tester.pumpAndSettle();
    expect(find.text('04:52'), findsOneWidget); // one minute earlier
    expect(find.text('Prishtinë: 1 minutë më herët se kohët bazë të Takvimit.'), findsOneWidget);
    expect(c.city.id, 'prishtine');
    expect((await SharedPreferences.getInstance()).getString('city'), 'prishtine');
    handle.dispose();
    await _close(tester);
  });

  testWidgets('hide the prayer times: only the card and the tips are left, then the sky fills the screen', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final c = await _open(tester);
    expect(find.text('Imsaku'), findsOneWidget);
    await tester.tap(find.text('Fshih vaktet'));
    await tester.pump();
    expect(c.focusOn, isTrue);
    expect(find.text('Imsaku'), findsNothing);
    expect(find.text('Shfaq vaktet'), findsOneWidget);
    expect(find.text('DY KËSHILLA PËR SOT'), findsOneWidget);
    expect(find.text('Për jetën'), findsOneWidget);
    expect(find.text('Si musliman'), findsOneWidget);
    // hide the tips too: the full-screen sky
    await tester.tap(_label('Fshih këshillat'));
    await tester.pump();
    expect(c.tipsOn, isFalse);
    expect(find.text('Për jetën'), findsNothing);
    expect(find.text('Shfaq'), findsOneWidget);
    expect(find.textContaining('01:14:00', findRichText: true), findsOneWidget);
    // both choices are remembered
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('focus'), isTrue);
    expect(prefs.getBool('tips'), isFalse);
    // bring everything back
    await tester.tap(find.text('Shfaq vaktet'));
    await tester.pump();
    expect(find.text('Imsaku'), findsOneWidget);
    handle.dispose();
    await _close(tester);
  });

  testWidgets('the settings are restored when the app starts again', (tester) async {
    final c = await _open(
      tester,
      prefs: {'city': 'peje', 'theme': 'dark', 'hijri': 1, 'alarm': 45, 'focus': true, 'tips': false},
    );
    expect(c.city.id, 'peje');
    expect(c.theme, ThemeChoice.dark);
    expect(c.hijriAdj, 1);
    expect(c.alarmOffset, 45);
    expect(c.focus && !c.tipsOn, isTrue);
    expect(find.text('23 Rebiul Ahir 1448 h.'), findsOneWidget); // Hijri date moved by +1
    await _close(tester);
  });

  testWidgets('settings: theme, Hijri correction and alarm', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await _open(tester);
    await tester.tap(_label('Cilësimet'));
    await tester.pumpAndSettle();
    expect(find.text('Pamja'), findsOneWidget);
    expect(find.text('Data hixhri'), findsOneWidget);
    await tester.tap(find.text('E errët'));
    await tester.pumpAndSettle();
    expect(c.theme, ThemeChoice.dark);
    await tester.tap(find.text('+1'));
    await tester.pumpAndSettle();
    expect(c.hijriAdj, 1);
    await tester.tap(find.text('60 min'));
    await tester.pumpAndSettle();
    expect(c.alarmOffset, 60);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme'), 'dark');
    expect(prefs.getInt('hijri'), 1);
    expect(prefs.getInt('alarm'), 60);
    await tester.tap(_label('Mbyll'));
    await tester.pumpAndSettle();
    expect(find.text('Cilësimet'), findsNothing);
    expect(find.text('23 Rebiul Ahir 1448 h.'), findsOneWidget);
    handle.dispose();
    await _close(tester);
  });

  testWidgets('month tab: the table, and tapping a day opens it', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await _open(tester);
    await tester.tap(_label('Muaji'));
    await tester.pump();
    expect(find.text('Tetor 2026'), findsOneWidget);
    expect(find.text('Ims.'), findsOneWidget);
    expect(find.text('04:52'), findsOneWidget); // 1 October
    await tester.tap(_label('Muaji tjetër'));
    await tester.pump();
    expect(find.text('Nëntor 2026'), findsOneWidget);
    await tester.tap(_label('Muaji i mëparshëm'));
    await tester.tap(_label('Muaji i mëparshëm'));
    await tester.pump();
    expect(find.text('Shtator 2026'), findsOneWidget);
    await tester.tap(_label('Muaji tjetër'));
    await tester.pump();
    await tester.tap(_label('E premte, 9 tetor'));
    await tester.pump();
    // tapped a day: back on the Today tab, showing that day
    expect(c.view, HomeView.today);
    expect(c.selected.d, 9);
    expect(find.text('E premte, 9 tetor 2026'), findsOneWidget);
    handle.dispose();
    await _close(tester);
  });

  testWidgets('on a wide screen the day and the month sit side by side', (tester) async {
    await _open(tester, size: const Size(1280, 800));
    expect(find.text('E shtunë, 3 tetor 2026'), findsOneWidget);
    expect(find.text('Tetor 2026'), findsOneWidget);
    expect(find.text('Sot'), findsNothing); // no tab bar
    expect(find.text('Hyrja e drekës'), findsWidgets);
    await _close(tester);
  });

  testWidgets('the date rolls over at midnight in Kosovo', (tester) async {
    var now = DateTime.utc(2026, 10, 3, 21, 59, 58).millisecondsSinceEpoch; // 23:59:58 in Kosovo
    SharedPreferences.setMockInitialValues({});
    final c = AppController(prefs: await SharedPreferences.getInstance(), clock: () => now);
    expect(c.today.d, 3);
    c.select(c.today.addDays(2)); // looking at another day: it must stay there
    now += 3000;
    c.tick();
    expect(c.today.d, 4);
    expect(c.selected.d, 5);
    c.selectToday();
    now = DateTime.utc(2026, 10, 4, 21, 59, 59).millisecondsSinceEpoch + 2000;
    c.tick();
    expect(c.today.d, 5);
    expect(c.selected.d, 5); // followed today
    c.dispose();
  });
}
