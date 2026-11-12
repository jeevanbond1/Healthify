# xtool spike gate (Windows → physical iPhone)

Run BEFORE any release work. The app build depends on this gate;
a red gate stops feature work until it is green.

## Steps

1. In WSL: `xtool setup`, `xtool auth`, `xtool sdk`
   (extracts Apple's SDK using your Apple ID).
2. `xtool new --help` sanity check (reference only — this repo
   already IS the SwiftPM project, do not scaffold over it).
3. `xtool dev` from this repo root with the iPhone USB-connected.
4. Confirm `NSCameraUsageDescription` made it into the installed app:
   open Foods → Scan → iOS must show the camera permission prompt
   with our reason string. If the app crashes instead, the key was
   lost in packaging — fix in the xtool/Info.plist path and re-run.

## Pass criteria (record evidence for each)

- [ ] `xtool dev` installs and launches on the iPhone. Evidence:
      photo/screenshot of the app running + terminal log tail.
- [ ] A Diary log + barcode scan + backup export/import round-trip
      completes on-device, airplane mode ON. Evidence: checklist in
      `docs/validation/device-qa-checklist.md` signed + dated.
- [ ] `swift test` passes for HealthifyCore (runnable on Linux/WSL;
      see "Host-side test evidence" below).

## If red

- Signing/SDK failure → fallback decision: cloud-Mac CI or a Mac
  build machine. Record the decision here, do not pile features
  onto a broken build path.
- Camera key lost → add/verify the Info.plist declaration in the
  xtool packaging path, reinstall, re-test Scan only.

## Host-side test evidence (this session)

- `swift test` (HealthifyCore, WSL Ubuntu): result recorded below.
- Atwater seed check: 16/16 pass (PowerShell, 2026-11-12).
- Backup format check: encode → validate → tamper-reject →
  merge-idempotent, covered by `Tests/HealthifyCoreTests/CoreTests.swift`.

Host-side result (2026-11-12): `swift test`, 9/9 green (see
`docs/validation/backup-checks.md`). iOS App target does not compile
on Linux by design (SwiftUI/AVFoundation need Apple's SDK) — that is
what the device run below proves.

## Spike run 2026-11-12 (host-side, no device) — GATE RED, blocked

Environment: WSL Ubuntu 26.04, Swift 6.4.2, xtool 1.24.0
(AppImage from GitHub releases), usbmuxd + libimobiledevice-utils
installed via apt. Observed output, verbatim:

- `xtool --version` → `xtool 1.24.0`
- `xtool sdk status` → `Not installed`
- `xtool devices` → no output in 30 s (timed out waiting on usbmuxd)
- `idevice_id -l` → `ERROR: Unable to retrieve device list!` (exit 255)
- Windows PnP check → no Apple Mobile Device / iPhone present
- `xtool setup` → interactive Apple login (API Key needs paid
  Developer membership; Password mode uses private APIs). Not run:
  no credentials supplied, and it blocks on a prompt.

What this proves: the Windows→WSL toolchain path works up to the
Apple-ID and USB boundary. Everything past that boundary needs you.

## Handoff needed to go green (exact items)

1. Plug an iPhone into this PC via USB, unlock it, tap "Trust".
2. USB into WSL: install usbipd-win on Windows and
   `usbipd bind`/`attach` the iPhone to Ubuntu (xtool docs point at
   Microsoft's USBIPD guide; fallback is the iTunes-relay workaround
   in xtool issue #19). Verify with `idevice_id -l` — it must print
   a UDID, not the ERROR above.
3. Apple ID: run `xtool setup` yourself (API Key if you have the paid
   Developer membership, else Password mode), then `xtool sdk`
   (downloads/extracts Xcode 27.1 SDK — Apple login in your browser).
   Re-run `xtool sdk status` until it no longer says `Not installed`.
4. From the repo root: `xtool dev`. Then work through
   `docs/validation/device-qa-checklist.md` in airplane mode and sign
   it. A successful `xtool dev` also type-checks the SwiftUI App
   target, which no Linux machine can do (Apple SDK only).

Device result: RED — awaiting items 1–4 above. Nothing in the repo
blocks them; the app, tests (9/9), and backup format are done.
