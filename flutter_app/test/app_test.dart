// Drives the real screens: changing the day, the city, the settings, the prayer times swiped up over the sky.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaktet/src/app.dart';
import 'package:vaktet/src/logic/day.dart';
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
  await tester.pumpWidget(VaktetApp(controller: controller, skyMotion: false));
  await tester.pump(const Duration(milliseconds: 100));
  return controller;
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

Finder _label(String text) => find.bySemanticsLabel(text);

/// Swipes the day's prayer times up over the full-screen sky.
Future<void> _openSheet(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('Rrëshqit lart për vaktet'));
  await tester.pumpAndSettle();
}

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
    await tester.pumpWidget(VaktetApp(controller: controller, skyMotion: false));
    await tester.pumpAndSettle();
    expect(find.textContaining('01:14:00', findRichText: true), findsOneWidget);
    now += 61 * 1000;
    controller.tick();
    await tester.pumpAndSettle();
    expect(find.textContaining('01:12:59', findRichText: true), findsOneWidget);
    await _close(tester);
  });

  testWidgets('after Jacia the card shows tomorrow and the alarm is on the sky itself', (tester) async {
    // 21:00 in Kosovo
    await _open(tester, at: DateTime.utc(2026, 10, 3, 19).millisecondsSinceEpoch);
    expect(find.text('NESËR'), findsOneWidget);
    expect(find.text('Imsaku'), findsWidgets);
    // no need to swipe up for it
    expect(find.text('Alarmi për sabah'), findsOneWidget);
    expect(find.text('30 min para lindjes së diellit (nesër 06:28)'), findsOneWidget);
    await _openSheet(tester);
    expect(find.textContaining('Nesër, 30 min para lindjes së diellit'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('the alarm stays on the sky until Imsaku, and is gone after it', (tester) async {
    // 03:30 in Kosovo: before Imsaku (04:53)
    final c = await _open(tester, at: DateTime.utc(2026, 10, 3, 1, 30).millisecondsSinceEpoch);
    expect(find.text('Alarmi për sabah'), findsOneWidget);
    expect(find.text('30 min para lindjes së diellit (sot 06:26)'), findsOneWidget);
    await _close(tester);
    c.dispose();
    // 05:00, after Imsaku: only in the sheet
    await _open(tester, at: DateTime.utc(2026, 10, 3, 3).millisecondsSinceEpoch);
    expect(find.text('Alarmi për sabah'), findsNothing);
    await _close(tester);
  });

  testWidgets('the alarm on the sky can be switched off', (tester) async {
    await _open(tester, prefs: {'f_homeAlarm': false}, at: DateTime.utc(2026, 10, 3, 19).millisecondsSinceEpoch);
    expect(find.text('Alarmi për sabah'), findsNothing);
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

  testWidgets('another day shows its own sky at this hour, its times, and a way back to today', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await _open(tester);
    await tester.tap(_label('Dita tjetër'));
    await tester.pumpAndSettle();
    expect(find.text('E diel, 4 tetor 2026'), findsOneWidget);
    expect(find.text('Kthehu te sot'), findsOneWidget);
    // the sky of 4 October at 18:38: Jacia is next that evening
    expect(find.text('NAMAZI I ARDHSHËM'), findsOneWidget);
    expect(find.text('Jacia'), findsWidgets);
    await _openSheet(tester);
    expect(find.text('VAKTET E DITËS'), findsOneWidget);
    expect(find.text('04:54'), findsOneWidget); // Imsaku on 4 October
    expect(find.text('DY KËSHILLA PËR KËTË DITË'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kthehu te sot'));
    await tester.pumpAndSettle();
    expect(c.isToday, isTrue);
    expect(find.text('E shtunë, 3 tetor 2026'), findsOneWidget);
    expect(find.text('Kthehu te sot'), findsNothing);
    await tester.tap(_label('Dita e mëparshme'));
    await tester.pumpAndSettle();
    expect(find.text('E premte, 2 tetor 2026'), findsOneWidget);
    await _openSheet(tester);
    expect(find.text('Xhumaja'), findsOneWidget);
    handle.dispose();
    await _close(tester);
  });

  testWidgets('swipe left for the next day, right for the day before', (tester) async {
    final c = await _open(tester);
    await tester.pumpAndSettle();
    await tester.flingFrom(const Offset(320, 450), const Offset(-220, 0), 1200);
    await tester.pumpAndSettle();
    expect(c.selected.d, 4);
    expect(find.text('E diel, 4 tetor 2026'), findsOneWidget);
    await tester.flingFrom(const Offset(70, 450), const Offset(220, 0), 1200);
    await tester.flingFrom(const Offset(70, 450), const Offset(220, 0), 1200);
    await tester.pumpAndSettle();
    expect(c.selected.d, 2);
    // a slow, short drag does nothing
    await tester.dragFrom(const Offset(200, 450), const Offset(-30, 0));
    await tester.pumpAndSettle();
    expect(c.selected.d, 2);
    // nor does a quick flick that hardly moves, or a long slow drag that is not far enough
    await tester.flingFrom(const Offset(200, 450), const Offset(-50, 0), 1500);
    await tester.pumpAndSettle();
    expect(c.selected.d, 2);
    await tester.timedDragFrom(const Offset(250, 450), const Offset(-100, 0), const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(c.selected.d, 2);
    // a swipe that starts at the very edge is the phone's Back gesture, not the next day
    await tester.flingFrom(const Offset(4, 450), const Offset(220, 0), 1200);
    await tester.pumpAndSettle();
    expect(c.selected.d, 2);
    // the moon of another day is that day's moon: 26 October is a full moon
    c.select(const Day(2026, 10, 26));
    expect(c.model.scene.moon.illumination, greaterThan(.97));
    await _close(tester);
  });

  testWidgets('changing the city moves the times and is remembered', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await _open(tester);
    await _openSheet(tester);
    expect(find.text('04:53'), findsOneWidget);
    await tester.tap(find.text('Kosovë').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prishtinë').last);
    await tester.pumpAndSettle();
    expect(find.text('04:52'), findsOneWidget); // one minute earlier
    expect(c.city.id, 'prishtine');
    expect((await SharedPreferences.getInstance()).getString('city'), 'prishtine');
    handle.dispose();
    await _close(tester);
  });

  testWidgets('today is the sky alone; the times, the alarm and the day\'s tips are swiped up', (tester) async {
    final handle = tester.ensureSemantics();
    // 21:00 in Kosovo, after Jacia: the alarm for tomorrow is suggested
    await _open(tester, at: DateTime.utc(2026, 10, 3, 19).millisecondsSinceEpoch);
    // no buttons to hide or show anything: just the sky, the countdown and the hint
    expect(find.text('Fshih vaktet'), findsNothing);
    expect(find.text('Shfaq vaktet'), findsNothing);
    expect(find.text('Shfaq'), findsNothing);
    expect(find.text('DY KËSHILLA PËR SOT'), findsNothing);
    expect(find.text('Rrëshqit lart për vaktet'), findsOneWidget);
    await _openSheet(tester);
    expect(find.text('VAKTET E SOTME'), findsOneWidget);
    expect(find.text('Imsaku'), findsWidgets);
    expect(find.text('Alarmi për sabah'), findsWidgets);
    expect(find.text('DY KËSHILLA PËR SOT'), findsOneWidget);
    expect(find.textContaining('Për jetën', findRichText: true), findsWidgets);
    expect(tester.takeException(), isNull);
    handle.dispose();
    await _close(tester);
  });

  testWidgets('full-screen sky: swipe up shows the prayer times, swipe down hides them', (tester) async {
    final handle = tester.ensureSemantics();
    await _open(tester);
    await tester.pumpAndSettle();
    expect(find.text('Rrëshqit lart për vaktet'), findsOneWidget);
    expect(find.text('Imsaku'), findsNothing);
    // a swipe from the very bottom edge (the phone's home gesture) leaves them hidden
    final h = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    await tester.flingFrom(Offset(195, h - 4), const Offset(0, -300), 1200);
    await tester.pumpAndSettle();
    expect(find.text('Imsaku'), findsNothing);
    // swipe up on the sky
    await tester.flingFrom(const Offset(195, 600), const Offset(0, -300), 1200);
    await tester.pumpAndSettle();
    expect(find.text('VAKTET E SOTME'), findsOneWidget);
    expect(find.text('Imsaku'), findsOneWidget);
    expect(find.text('Jacia'), findsWidgets);
    expect(tester.takeException(), isNull);
    // swipe down hides them again
    await tester.flingFrom(const Offset(195, 500), const Offset(0, 300), 1200);
    await tester.pumpAndSettle();
    expect(find.text('Imsaku'), findsNothing);
    // a slow drag that goes less than half way springs back shut
    await tester.dragFrom(const Offset(195, 600), const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(find.text('Imsaku'), findsNothing);
    // the hint opens them too, and Back closes them
    await tester.tap(find.text('Rrëshqit lart për vaktet'));
    await tester.pumpAndSettle();
    expect(find.text('Imsaku'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Imsaku'), findsNothing);
    expect(find.text('Rrëshqit lart për vaktet'), findsOneWidget);
    handle.dispose();
    await _close(tester);
  });

  testWidgets('the settings are restored when the app starts again', (tester) async {
    final c = await _open(tester, prefs: {'city': 'peje', 'theme': 'dark', 'hijri': 1, 'alarm': 45});
    expect(c.city.id, 'peje');
    expect(c.theme, ThemeChoice.dark);
    expect(c.hijriAdj, 1);
    expect(c.alarmOffset, 45);
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

  testWidgets('settings: font, text size and countdown thickness', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await _open(tester);
    double countdownWeight() {
      final text = tester.widget<RichText>(find.textContaining('01:14:00', findRichText: true));
      return text.text.style!.fontVariations!.single.value;
    }

    expect(countdownWeight(), 900);
    await tester.tap(_label('Cilësimet'));
    await tester.pumpAndSettle();
    expect(find.text('Stili i shkronjave'), findsOneWidget);
    await tester.tap(find.text('Klasike'));
    await tester.pumpAndSettle();
    expect(c.font, FontChoice.lora);
    expect(Theme.of(tester.element(find.text('Pamja'))).textTheme.bodyMedium!.fontFamily, 'Lora');
    await tester.tap(find.text('E madhe'));
    await tester.pumpAndSettle();
    expect(c.fontScale, 1.12);
    expect(MediaQuery.textScalerOf(tester.element(find.text('Pamja'))).scale(100), closeTo(112, .01));
    await tester.tap(find.text('Hollë'));
    await tester.pumpAndSettle();
    expect(c.countdownWeight, 300);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('font'), 'lora');
    expect(prefs.getDouble('fontScale'), 1.12);
    expect(prefs.getInt('countdownWeight'), 300);
    await tester.tap(_label('Mbyll'));
    await tester.pumpAndSettle();
    expect(countdownWeight(), 300);
    handle.dispose();
    await _close(tester);
  });

  testWidgets('swipe down for the month; the table, and tapping a day opens it', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await _open(tester);
    await tester.pumpAndSettle();
    expect(find.text('Sot'), findsNothing); // no tabs any more
    expect(find.text('Muaji'), findsNothing);
    // a short pull springs back
    await tester.dragFrom(const Offset(195, 300), const Offset(0, 40));
    await tester.pumpAndSettle();
    expect(c.view, HomeView.today);
    await tester.flingFrom(const Offset(195, 300), const Offset(0, 260), 1200);
    await tester.pumpAndSettle();
    expect(c.view, HomeView.month);
    expect(find.text('Tetor 2026'), findsOneWidget);
    expect(find.text('Ims.'), findsOneWidget);
    expect(find.text('04:52'), findsOneWidget); // 1 October
    await tester.tap(_label('Muaji tjetër'));
    await tester.pumpAndSettle();
    expect(find.text('Nëntor 2026'), findsOneWidget);
    await tester.tap(_label('Muaji i mëparshëm'));
    await tester.tap(_label('Muaji i mëparshëm'));
    await tester.pumpAndSettle();
    expect(find.text('Shtator 2026'), findsOneWidget);
    await tester.tap(_label('Muaji tjetër'));
    await tester.pumpAndSettle();
    await tester.tap(_label('E premte, 9 tetor'));
    await tester.pumpAndSettle();
    // tapped a day: back on the Today tab, showing that day
    expect(c.view, HomeView.today);
    expect(c.selected.d, 9);
    expect(find.text('E premte, 9 tetor 2026'), findsOneWidget);
    // the hint opens it too, and Back (or swiping up from the bottom) returns to the sky
    await tester.tap(find.text('Rrëshqit poshtë për muajin'));
    await tester.pumpAndSettle();
    expect(c.view, HomeView.month);
    expect(find.text('DITËT E SHËNUARA'), findsOneWidget);
    expect(find.textContaining('Kalimi në kohën dimërore'), findsOneWidget); // 25 October
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(c.view, HomeView.today);
    await tester.tap(find.text('Rrëshqit poshtë për muajin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rrëshqit lart për t\'u kthyer'));
    await tester.pumpAndSettle();
    expect(c.view, HomeView.today);
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

  testWidgets('a holiday, a great night and the Friday look show on the sky', (tester) async {
    // Monday 16 March 2026, 12:00 in Kosovo: the evening brings Nata e Kadrit
    var c = await _open(tester, at: DateTime.utc(2026, 3, 16, 11).millisecondsSinceEpoch);
    expect(find.text('Sonte: Nata e Kadrit'), findsOneWidget);
    expect(find.text('26 Ramazan 1447 h.'), findsOneWidget); // the BIK Takvim's date
    await _close(tester);
    c.dispose();
    // 17 February: Independence Day
    c = await _open(tester, at: DateTime.utc(2026, 2, 17, 11).millisecondsSinceEpoch);
    expect(find.text('Dita e Pavarësisë së Kosovës · festë zyrtare'), findsOneWidget);
    await _close(tester);
    c.dispose();
    // Friday 9 October 2026, 11:00 in Kosovo
    c = await _open(tester, at: DateTime.utc(2026, 10, 9, 9).millisecondsSinceEpoch);
    expect(find.text('E xhuma · Xhuma mubarek'), findsOneWidget);
    expect(find.text('Koha e namazit Duha (nafile), deri në 12:16'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _close(tester);
    c.dispose();
    // all of it can be switched off
    c = await _open(
      tester,
      prefs: {'f_fridayLook': false, 'f_nafile': false, 'f_hints': false, 'f_hijri': false},
      at: DateTime.utc(2026, 10, 9, 11).millisecondsSinceEpoch,
    );
    expect(find.text('E xhuma · Xhuma mubarek'), findsNothing);
    expect(find.textContaining('Duha'), findsNothing);
    expect(find.text('Rrëshqit lart për vaktet'), findsNothing);
    expect(find.text('Rrëshqit poshtë për muajin'), findsNothing);
    expect(find.textContaining('Rebiul Ahir'), findsNothing);
    await _close(tester);
    c.dispose();
  });

  testWidgets('settings: the features can be switched off and on', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await _open(tester);
    await tester.tap(_label('Cilësimet'));
    await tester.pumpAndSettle();
    expect(find.text('Veçoritë'), findsOneWidget);
    expect(find.text('Lëvizja e qiellit'), findsNothing); // removed
    await tester.scrollUntilVisible(find.text('Sugjerime për namaze nafile'), 200);
    await tester.tap(find.text('Sugjerime për namaze nafile'));
    await tester.pumpAndSettle();
    expect(c.on(Feature.nafile), isFalse);
    expect((await SharedPreferences.getInstance()).getBool('f_nafile'), isFalse);
    await tester.tap(find.text('Sugjerime për namaze nafile'));
    await tester.pumpAndSettle();
    expect(c.on(Feature.nafile), isTrue);
    handle.dispose();
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
