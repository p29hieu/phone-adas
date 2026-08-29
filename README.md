# Phone ADAS

Driver-assistance HUD for Vietnam's safe-following-distance rules (Thông tư
38/2024/TT-BGTVT). Measures the distance to the lead vehicle with the phone
camera + on-device AI, warns on tailgating / forward collision / lead
departure at red lights, and shows GPS speed, coordinates, area name and
local weather.

**Status — Phase 2 (iOS vision core)**: live camera preview + YOLO11n on
the Neural Engine with per-frame camera intrinsics feeding the distance
math. Android still runs the mock emitter (phase 3). GPS self-calibration
of per-class vehicle widths is the remaining phase-2 item.

- Bundle ID: `app.mikosea.test` (placeholder, will change)
- iOS-first (tested on iPhone XS / 12 Pro), Android buildable throughout.

## Toolchain — strictly pinned

| Tool | Version | Pinned by |
|---|---|---|
| Flutter | **3.47.2** | `.fvmrc` (FVM) |
| Dart | 3.13.2 | comes with Flutter above |
| Packages | exact | `pubspec.lock` (committed) |

Rules:
- **Never run bare `flutter`** — always `fvm flutter …` (or use the
  `.fvm/versions/3.47.2` SDK configured in `.vscode/settings.json`).
- Upgrading Flutter = edit `.fvmrc` + run `fvm install` + commit the diff of
  `.fvmrc` and `pubspec.lock` in one PR.

## Supported devices

| Platform | Minimum | Reason |
|---|---|---|
| iOS | **iOS 15.0** + **A12 Bionic** (iPhone XS/XR, 2018+) | iOS 15 is required by Firebase iOS SDK 12 / Flutter 3.47; A12 is the first chip whose Neural Engine is available to Core ML — the phase-2 vision core targets the ANE. A11 and older would fall back to GPU (3-4x slower, hotter) and are not supported. |
| Android | **Android 8.0 (API 26)**, Adreno 640-class GPU or better recommended | Below API 26 CameraX is unreliable and hardware cannot sustain 10 fps inference. NPU acceleration (optional) needs Hexagon v68+ (Snapdragon 888 / 7+ Gen 2 and newer) or Google Tensor; otherwise the LiteRT GPU delegate is used. |

## Setup on a new machine (macOS)

```bash
# 1. Prerequisites: Xcode (App Store), CocoaPods, Homebrew
brew tap leoafarias/fvm && brew install fvm

# 2. Clone and restore the exact toolchain
git clone git@github.com:p29hieu/phone-adas.git && cd phone-adas
fvm install          # reads .fvmrc -> installs Flutter 3.47.2
fvm flutter pub get  # restores exact versions from pubspec.lock

# 3. Run (device or simulator)
fvm flutter run
```

Android: install Android Studio + SDK, then `fvm flutter run` on an
emulator/device. No other per-machine configuration.

## Firebase / Crashlytics

The app runs fine **without** Firebase (init is guarded; Crashlytics calls
no-op). To activate crash reporting:

```bash
dart pub global activate flutterfire_cli
flutterfire configure   # pick/create the Firebase project, both platforms
```

Then for Android, add the two gradle plugins the FlutterFire docs list
(`com.google.gms.google-services`, `com.google.firebase.crashlytics`) —
they are intentionally not pre-added so the project builds before Firebase
is configured. iOS needs no manual step. Crashlytics buffers offline and
uploads when a connection returns.

Every Bloc transition is logged as a Crashlytics breadcrumb
(`lib/app/app_bloc_observer.dart`); the 10 Hz HUD cubit logs only
significant transitions (alerts, departures, status).

## Architecture

```
lib/
├── domain/        # pure Dart, no Flutter deps, fully unit-tested
│   ├── safe_distance.dart      # TT 38/2024 legal gap table
│   ├── collision_warning.dart  # TTC + hysteresis alert state machine
│   ├── lead_departure.dart     # red-light departure detector
│   ├── distance_estimator.dart # pinhole d = W·f/w + lead pick
│   └── solar.dart              # offline sunrise/sunset (auto theme)
├── core/adas_channel.dart      # bridge to native vision cores
├── services/weather_service.dart  # Open-Meteo, offline-cached
├── features/
│   ├── hud/       # HudCubit (sensor fusion) + HUD screen
│   └── settings/  # theme (auto-by-sun/light/dark), locale (vi/en)
└── app/app_bloc_observer.dart  # Bloc -> Crashlytics breadcrumbs
```

**Native channel contract** (identical on iOS, Android, and the future
external-UVC source):

- `EventChannel app.mikosea.test/detections` → ~10 Hz maps:
  `{ts, mock, frameW, frameH, fx?, detections: [{cls, conf, x, y, w, h}]}`
  (bbox in full-resolution frame pixels; `cls` ∈ car|truck|bus|motorcycle;
  `fx` = per-frame focal length in pixels from camera intrinsics when the
  platform provides it)
- `MethodChannel app.mikosea.test/control` → `start` returns
  `{textureId: int?}` (live-preview Flutter texture; null on the simulator /
  Android stub / permission denied) / `stop`

Native cores: `ios/Runner/AdasCore.swift` — real vision pipeline
(AVCapture 1080p → Flutter texture + intrinsics → Vision ROI → YOLO11n on
the Neural Engine; falls back to the mock emitter on the simulator or when
the model is missing). `android/.../AdasCore.kt` — mock emitter (phase 3).

### iOS model

`ios/Runner/Models/yolo11n.mlmodelc` (5.3 MB, FP16, NMS pipeline) is
committed so every checkout builds identically. To regenerate it (e.g. to
try a bigger model):

```bash
./tools/export_model.sh   # needs python3.12; torch is version-pinned inside
```

Without the model the app still runs — live preview + mock detections.
YOLO11 weights are AGPL-3.0: fine for personal use, re-check before any
public distribution.

## Testing

```bash
fvm flutter test      # domain + settings suites
fvm flutter analyze
```

Domain logic (legal table, TTC, hysteresis, departure, solar, pinhole math)
is 100% covered by `test/domain/`.

## Roadmap

1. ~~Scaffold, mock pipeline, HUD, alerts, i18n, theming~~ ← here
2. iOS vision core: AVCapture → Vision (ROI) → YOLO11n Core ML on ANE,
   camera intrinsics for f, GPS self-calibration of per-class widths
3. Android vision core: CameraX → center-crop → LiteRT (GPU/QNN)
4. Google sign-in, AI assistant, live traffic sharing, in-app map, SOS call
5. External range sensors, starting with the car's factory ACC radar over
   CAN bus (OBD/ESP32 -> BLE/TCP -> a Dart-level range source; radar then
   drives lead distance + measured closing speed in CollisionMonitor, while
   the camera keeps multi-vehicle overlay and classification)
6. External UVC camera source + car-screen projection (rooted Android)
