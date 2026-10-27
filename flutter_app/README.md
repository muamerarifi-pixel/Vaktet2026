# Vaktet – Flutter app

The Android app for [Vaktet](../README.md): prayer times for the towns of Kosovo from the official Takvim of the
Islamic Community of Kosovo (BIK). It is a Flutter port of the web app in the repository root and looks and behaves
the same: the sky card that follows the prayer time, active prayer indicator pill ("Ikindia tashmë ka hyrë"), centered symmetrical layout, forbidden times, hide-the-times mode with daily tips, the Sabah
alarm suggestion, the month table, Hijri date with correction, light/dark/automatic theme, a choice of font, text size and countdown thickness, 19 towns. Works fully
offline.

## What's new in v1.9.12

- **Detailed Botanical Leaf Contours (No More Circles):** Canopy rendered with >1,000 individual lanceolate leaves featuring sharp acute apices, tapered petiole bases, dual-facet 3D illumination, and delicate central midrib veins.
- **Sprig Branch Distribution & Wind Flutter:** Foliage arranged along terminal twigs radiating outward with natural angle variance and micro-fluttering wind animation.
- **Realistic Fallen Leaves:** Autumn ground cover rendered with true leaf geometry.

## What's new in v1.9.11

- **Dynamic Water Surface & Reflections:** Perspective horizontal shimmer lines, breathing radial light paths under sun and moon, and slow-drifting bezier ripples.
- **Frosted Glass Settings Sheet:** Sleek glassmorphism with high-sigma backdrop blur, dual soft drop shadows, and subtle scale-fade dialog entrance.
- **Organic Foreground Tree & Wind Sway:** Tapered branch contours with root flares, 3-layer organic leaf clusters, seasonal foliage rim lighting, and harmonic wind effect.
- **Manrope Light Font:** Integrated clean, modern Manrope Light typography option for text and countdown.
- **Refined Micro-interactions:** Smooth sliding countdown digit transitions with stationary baseline anchoring to eliminate row jitter, plus subtle haptic feedback.
## What's new in v1.9.10

- **Active Prayer Indicator Pill:** Shows which prayer is currently active (e.g., *"Ikindia tashmë ka hyrë"*, *"Dreka tashmë ka hyrë"*, *"Dielli tashmë ka lindur"*) directly above the "NAMAZI I ARDHSHËM" header, with a frosted glass badge and an active green pulse.
- **Symmetric Centered Layout:** All primary card elements are unified into a single vertically and horizontally centered stack for balance on phones of all aspect ratios and resolutions.
- **Clock Synchronization with Device Status Bar:** Automatically compensates for device wall-clock offsets during daylight saving transitions so the in-app countdown and system clock are always in sync.

## Get the APK

The APKs are built by GitHub Actions (`.github/workflows/android-apk.yml`) on every push that touches
`flutter_app/`, one per processor type (`flutter build apk --split-per-abi`): `vaktet-arm64.apk` for nearly every
phone of the last years and `vaktet-arm32.apk` for older ones, each about a third of the size of one APK for all.

1. Open the repository's **Actions** tab → **Android APK** → the latest run.
2. Download the **vaktet-apk** artifact (a zip with both APKs) and unzip it.
3. Copy `vaktet-arm64.apk` to the phone and open it (allow "install unknown apps" for your browser/file manager
   once).

To publish them as a GitHub Release: run the workflow by hand (**Run workflow**, tick **Publish a release**), or
push a tag like `v1.0.0`. The newest is then always at
<https://github.com/muamerarifi-pixel/Vaktet2026/releases/latest/download/vaktet-arm64.apk>.

Split APKs get a version code of 1000 × the processor type + the build number (arm64: 2000 + …), so going back to a
single APK for all processors later would need a build number above that, or Android refuses the downgrade.

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
| `lib/src/state/` | `AppController`: settings (kept on the phone), selected day, the ticking clock synced with device status bar |
| `lib/src/ui/` | The screens: sky painter, next-prayer card with active pill, Today, Month, Settings, home layout (phone and tablet) |
| `assets/fonts/` | Figtree, Nunito, Lora, JetBrains Mono – variable fonts subset to Latin (SIL Open Font License) |
| `test/` | Unit, widget and layout tests, and the web-parity test (below) |
| `tool/` | `gen_web_reference.mjs`, which records what the web app shows, for the parity test |

### Times and summer time

The Takvim stores times in standard time (UTC+1). The app adds summer time itself with the EU rule (last Sunday of
March to last Sunday of October, 01:00 UTC), and synchronizes with the device's wall-clock time so the countdown and status bar clock always match up to the second without timezone discrepancies. The Takvim repeats by calendar date every year, and 29 February uses the times of 28 February.

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
