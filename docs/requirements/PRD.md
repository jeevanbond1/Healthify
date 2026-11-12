# PRD — Healthify (working title, local-only diet + gym tracker)

## Personas

- P1: Indian home cook tracking dal-roti-rice macros without internet.
- P2: Gym-goer logging push/pull/legs sets, reps, weight progression.
- P3: Crash victim: reinstalls and restores everything from a backup file.

## MVP stories + acceptance criteria

1. Onboard locally: enter sex, age, height, weight, activity, goal,
   weekly rate → targets shown. No login screen exists anywhere.
   AC: airplane mode, first launch reaches diary in < 2 min.
2. Log a meal: search "dal" → pick item → choose serving → logged with
   macros + micros. AC: ≤ 4 taps from Diary; source badge visible.
3. Barcode: scan/enter code → match logs in seconds; unknown code →
   guided custom-food creation. AC: miss path never dead-ends.
4. Custom food/recipe: create once, reuse, included in backup.
   AC: per-100 g nutrients required before save; recipe needs a name,
   ≥ 1 weighed/measured ingredient, and servings > 0, with live
   per-serving totals shown before saving; saved recipes log in
   one tap from Foods → My recipes.
5. Diary day: meals grouped, totals vs targets, micros section, water,
   remaining calories. AC: edit/delete entry updates totals instantly.
6. Water/weight: log intake and weigh-ins; history visible.
7. Gym: start routine or empty workout → log sets → rest timer →
   finish summary (volume, PRs) → history + per-exercise progress.
   AC: full session completable offline; units kg/lb switchable.
8. Backup: export one file via share sheet; delete/reinstall/import →
   identical data (diff-verified). Corrupt file rejected, data untouched.
9. Settings: edit goals/units, backup reminder toggle, data sources
   (USDA public domain, OFF ODbL attribution), delete-all with confirm.

## Later (not MVP)

Fasting timer, charts polish, more seed foods,
iCloud Drive auto-backup note, localisation. (Apple Health read-only
import — incl. scale apps like HealthU+ — is now MVP scope.)

## Non-functional

- Zero network calls in normal use; fully usable in airplane mode.
- Atomic writes; crash mid-save never corrupts existing data.
- No medical claims; general-wellness disclaimer; under-18 guidance.
- App Store privacy: no data collected. App size target ≤ 150 MB.
