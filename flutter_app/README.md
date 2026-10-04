# Vaktet – Flutter app

The Android app for [Vaktet](../README.md): prayer times for the towns of Kosovo from the official Takvim of the
Islamic Community of Kosovo (BIK). It is a Flutter port of the web app in the repository root and looks and behaves
the same: the sky card that follows the prayer time, forbidden times, hide-the-times mode with daily tips, the Sabah
alarm suggestion, the month table, Hijri date with correction, light/dark/automatic theme, 19 towns. Works fully
offline.

## Get the APK

The APK is built by GitHub Actions (`.github/workflows/android-apk.yml`) on every push that touches `flutter_app/`:

1. Open the repository's **Actions** tab → **Android APK** → the latest run.
2. Download the **vaktet-apk** artifact (a zip with `vaktet-<commit>.apk`) and unzip it.
3. Copy the `.apk` to the phone and open it (allow "install unknown apps" for your browser/file manager once).

To publish it as a GitHub Release (a direct download link): run the workflow by hand (**Run workflow**, tick
**Publish a release**), or push a tag like `v1.0.0`.

The release APK is signed with Flutter's debug key, which is fine for installing it yourself. To publish on Google Play
you need your own upload key – see <https://docs.flutter.dev/deployment/android#sign-the-app>.

## Build it yourself

You need Flutter 3.47 (stable) and the Android SDK (Android Studio installs it).

```sh
cd flutter_app
flutter pub get
flutter test                 # logic, screens and layouts
flutter run                  # on a connected phone / emulator
flutter build apk --release  # build/app/outputs/flutter-apk/app-release.apk
```

## How it is built

| Path | What it does |
|---|---|
| `lib/src/logic/` | Pure Dart, no UI: the BIK times and summer-time rule, prayer rows, forbidden times, sky phase and sun/moon position, next-prayer card, alarm suggestion, Hijri date, daily tips |
| `lib/src/data/` | Generated data: the Takvim (`vaktet_base.dart`), the tips, the Umm al-Qura month table |
| `lib/src/state/` | `AppController`: settings (kept on the phone), selected day, the ticking clock |
| `lib/src/ui/` | The screens: sky painter, next-prayer card, Today, Month, Settings, home layout (phone and tablet) |
| `assets/fonts/` | Figtree (SIL Open Font License) |
| `test/` | Unit, widget and layout tests, and the web-parity test (below) |
| `tool/` | `gen_web_reference.mjs`, which records what the web app shows, for the parity test |

### Times and summer time

The Takvim stores times in standard time (UTC+1). The app adds summer time itself with the EU rule (last Sunday of
March to last Sunday of October, 01:00 UTC), so it needs no time-zone database and the times stay correct in the years
to come. The Takvim repeats by calendar date every year, and 29 February uses the times of 28 February. This is the same
as the web app.

### Hijri date

The month starts of the Umm al-Qura calendar for 2025–2077 are in `lib/src/data/hijri_umalqura.dart`, generated from
ICU (what the web app reads through `Intl`). Outside that range the Hijri line is left empty.

### The web app is the reference

`test/web_parity_test.dart` checks the Dart logic against what the original web app shows. The fixture
`test/fixtures/web_reference.json` was recorded by loading the web app in Chromium with a faked clock (edges of every
prayer time, summer-time switch days, Fridays, 29 February, forbidden times, every town) and storing the visible text:
dates, Hijri dates, next prayer, countdown, alarm, the list, the sky phase, the sun position, the tips and the month
tables. To record it again (needs Playwright):

```sh
PLAYWRIGHT_MODULE=/path/to/playwright node tool/gen_web_reference.mjs .. test/fixtures/web_reference.json 7
```

If you change `data.js` or `tips.js` in the web app, regenerate `lib/src/data/*.dart` from them too.
