# Phone ADAS — project instructions

Flutter app measuring distance to the lead vehicle (VN Thông tư 38/2024 safe
gaps) with on-device AI. iOS-first, Android kept buildable.

## Toolchain (strict)

- Flutter **3.47.2** via FVM — ALWAYS `fvm flutter …`, never bare `flutter`.
- Exact dep versions live in `pubspec.lock` (committed). Don't upgrade
  casually; `.fvmrc` + `pubspec.lock` change together in a dedicated commit.

## Conventions

- State management: **Bloc/Cubit** (chosen for Crashlytics-traceable
  transitions). Every new bloc/cubit relies on `AppBlocObserver` for
  breadcrumbs; high-frequency cubits must opt out (see `_noisyBlocs`) and
  log significant transitions manually via `crashlyticsLog`.
- `lib/domain/` stays pure Dart (no Flutter imports) and unit-tested —
  alert logic changes REQUIRE a test in `test/domain/`.
- Code comments, commit messages, PR text: English. UI strings: only via
  l10n ARB files (`lib/l10n/app_{en,vi}.arb`) — keep both languages in sync,
  then run `fvm flutter gen-l10n`.
- Firebase is optional at runtime: never call Firebase APIs without the
  `Firebase.apps.isNotEmpty` guard (see `crashlyticsLog`).
- Native channel contract is frozen (see README; includes optional `fx`
  per frame and `start -> {textureId}`). Changing it means updating BOTH
  native cores + `AdasChannel` + this note.
- iOS model: `./tools/export_model.sh` produces
  `ios/Runner/Models/yolo11n.mlmodelc`; the core falls back to mock
  detections when it is absent, so the build never depends on it.
- Planned external range sources (factory ACC radar via CAN/OBD) enter at
  the DART layer, not the platform channel: they feed
  `CollisionMonitor.update(measuredClosingMps: ...)` and lead distance
  directly. Camera remains the only source of bboxes/classes.

## Commands

```bash
fvm flutter test && fvm flutter analyze   # must pass before commit
fvm flutter run                           # device/simulator
fvm flutter gen-l10n                      # after editing .arb files
```

## Safety framing

This is a driver-assist aid, not a certified safety system. Distance values
are estimates (±10%); alerts supplement, never replace, driver attention.
Keep that framing in all UI copy and store listings.
