# Feature inventory (clean-room, behaviour only)

Scope rule: AI features are **out**. Local-only, no login. Gym tracking
is **in**. Each row: what the user does, what our MVP does instead.

## Diet tracking

- Log by search: both apps offer it; free on both. MVP: yes, offline,
  against bundled DB with ranked search.
- Log by barcode: MFP Premium; HealthifySnap is photo-AI (out of scope).
  MVP: manual barcode entry + camera scan, matched against bundled
  Open-Food-Facts subset; miss path = create custom food.
- Photo/voice AI logging: out of scope permanently for this plan.
- Food detail: macros + micros per serving. MVP: same, plus per-100 g
  view and source/verification badge on every item.
- Custom foods + recipes: MFP supports both. MVP: both, stored locally,
  included in backup.
- Diary: breakfast/lunch/dinner/snacks, daily totals, remaining calories.
  MVP: yes, identical structure.
- Water, weight: both track them. MVP: yes, local history.

## Goals

- MFP: BMR (Mifflin-St Jeor) + activity + weekly-rate adjustment, BMI
  floor. MVP: same formula, minimum calorie floors, capped weekly rate,
  macro split editable. No account needed; all inputs stay on device.

## Gym tracking (our first-class section)

- Neither reference is a gym app; MFP logs generic exercise calories.
- MVP scope (designed, not copied): exercise library by muscle group and
  equipment, custom exercises, routine templates, live session logging
  (sets x reps x weight, timed/cardio entries), rest timer, history
  calendar, total volume, personal records, per-exercise progress.

## Data portability (our differentiator)

- Neither reference offers file-level backup/restore as a core flow.
- MVP: one versioned backup file (JSON), export via share sheet, import
  with preview + replace/merge, pre-import snapshot, optional password
  encryption, CSV export for diary and workouts.

## Explicit non-goals

AI coach, photo/voice AI, meal plans, fasting timer, social/community,
accounts, backend sync, analytics, ads, paywall. Apple Health
read-only import (weight/body-comp incl. HealthU+, nutrition, workouts)
is in scope; nothing is ever written back or uploaded.
