# Healthify (working title)

Local-only iPhone diet + gym tracker. No login, no backend, no network
calls in normal use. SwiftUI + SwiftPM, built from Windows via
[xtool](https://github.com/xtool-org/xtool).

## Layout

- `Sources/HealthifyCore` — portable logic (Foundation only): models,
  goal engine, workout stats, backup codec, JSON document store,
  seed foods + exercises.
- `Sources/HealthifyApp` — SwiftUI: Diary, Foods, Workouts, Progress,
  Settings, onboarding, barcode scanner, design system.
- `Tests/HealthifyCoreTests` — engine, Atwater, backup round-trip /
  tamper / merge, volume + PR tests.
- `docs/` — research teardown (public evidence only) + PRD + data dictionary.

## Build with xtool (Windows/WSL)

1. `xtool setup`, `xtool auth`, `xtool sdk` (extracts Apple's SDK
   with your Apple ID).
2. `xtool dev` — build + install on your USB-connected iPhone.
3. `xtool install` for a packaged `.ipa`.

Spike gate (passes before release work): hello-world install works,
plus a Diary log + barcode scan + backup export/import round-trip
on-device, all in airplane mode.

Packaging note: the app target's `Info.plist` must declare
`NSCameraUsageDescription` (barcode scanner), or iOS kills the scan.
xtool generates the app bundle — confirm the key survives packaging
during the spike.

## Backup format (v1)

One JSON file: `schemaVersion`, `exportedAt`, per-collection `counts`,
FNV-1a `checksum` over the deterministically-encoded body, then the
body. Import validates version + checksum, shows counts, then
Replace or Merge in one atomic write; a pre-import snapshot enables
Undo. Tampered files are rejected with data untouched.

## UI principles (from the Apple-design skill, applied natively)

- Critically-damped springs (`.spring(response: 0.35, dampingFraction: 1)`)
  by default; bounce only for flick-driven motion.
- Press feedback on touch-down, haptics on commits (log, PR, import),
  error haptic on rejections.
- Translucent `.ultraThinMaterial` chrome with content scrolling under.
- Reduced-motion users get short cross-fades instead of springs.
- Destructive actions confirm; import is undoable.

## Privacy & sources

No data collected, no network. Food data: USDA FoodData Central
(public domain), Open Food Facts (ODbL — attribution in Settings),
curated Indian foods marked as estimates. General wellness guidance
only, not medical advice.
