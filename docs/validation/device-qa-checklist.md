# Device QA checklist (run on a physical iPhone, airplane mode ON)

Preconditions: app installed via `xtool dev`, no network (airplane mode),
fresh install (delete app first to clear the sandbox).

## Diet

- [ ] First launch shows onboarding, no login screen anywhere.
- [ ] Enter profile → targets shown; matches Mifflin-St Jeor recompute
      (spot-check one profile by hand).
- [ ] Diary: log breakfast + lunch + dinner via search (e.g. "dal",
      "roti", "rice"). Each logs in ≤ 4 taps; totals update instantly.
- [ ] Food detail shows per-serving AND per-100 g, source badge
      (Verified vs Estimate) on every item.
- [ ] Barcode: scan a packaged food or type its code. Match → log in
      seconds. No match → "Create this food" path completes and the
      new food is searchable afterwards.
- [ ] Edit a logged entry's grams; delete an entry. Day totals update.
- [ ] Water: add 250 ml twice → 500 ml shown. Weight: two weigh-ins →
      trend shown in Progress.
- [ ] Kill the app mid-logging (swipe away), relaunch: earlier data intact.

## Gym

- [ ] Start "Full body A" → log 3 sets with reps + weight → rest timer
      60 s runs, haptic fires at zero → Finish → summary shows volume
      and duration → Save lands in History.
- [ ] Log a heavier set next session → PR appears in Progress.
- [ ] Start empty workout, add an exercise via picker, finish, delete
      the session from History.

## Backup / crash recovery (the critical path)

- [ ] Settings → Export backup → file saves via share sheet.
- [ ] Delete the app (removes the sandbox), reinstall, Import the file
      → Replace → diary, workouts, custom foods, goals identical
      (compare entry counts + one full day by hand).
- [ ] Import a corrupted file (edit one digit in a text editor) →
      clear error, current data untouched.
- [ ] Import with Merge twice → second run reports "0 added" everywhere.

## Offline + privacy

- [ ] Entire checklist above passes with zero network (airplane mode).
- [ ] Privacy labels: no data collected. No login, no analytics prompts.

## Apple Health + scale (needs network OFF, Health data ON)

Precondition: in HealthU+ (or your scale app), enable Apple Health sync
for Weight, Body Fat %, Lean Body Mass and BMI; step on the scale.

- [ ] Settings → Connect Apple Health → grant Weight, Body Fat, Lean
      Mass, Nutrition, Workouts, Water → status shows Connected.
- [ ] Sync now → weigh-in appears with fat % and lean mass attached;
      “last synced” timestamp updates; second sync reports no duplicates.
- [ ] Delete one imported weigh-in in the Health app → Sync now →
      the copy disappears here, manual entries untouched.
- [ ] Deny a category in Settings → Privacy & Security → Health →
      sync still completes for the granted ones.

Sign-off: ______________ date: __________ build: __________
