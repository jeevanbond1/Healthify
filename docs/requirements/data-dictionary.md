# Data dictionary

All nutrients stored **per 100 g** on `FoodItem`; scaled by
`grams / 100` at log time; the scaled snapshot is stored on the entry
so history never shifts when seed data updates.

## NutrientProfile (per 100 g)

Energy kcal; protein/carbs/fat/fibre/sugar/saturated-fat in g; sodium,
potassium, calcium, iron, magnesium, zinc, vitamin C in mg; vitamin A,
vitamin D, B12, folate in mcg. Atwater cross-check at seed import:
`4*protein + 4*carbs + 9*fat ≈ kcal` within 15% or item is flagged.

## Entities

- `FoodItem`: id, name, brand?, barcode?, servingGrams, servingLabel,
  nutrientsPer100g, source{name, license}, verified Bool, tags[],
  units[] (`ServingUnit{label, grams}` — explicit per-food cup/katori/
  piece/glass conversions, no density guessing).
  Bundled items are read-only; user copies become custom foods.
- Portions resolve to grams via `PortionMath` ("g" passthrough,
  "serving" = servingGrams, else the food's listed unit; unknown unit
  or zero amount → nil, never silent 0 g).
- `FoodSource`: "USDA FoodData Central" (public domain),
  "Open Food Facts" (ODbL, attribution in Settings),
  "Curated estimate" (verified=false, user-correctable).
- `Recipe`: id, name, ingredients[foodId, grams], servings; per-serving
  nutrients computed, never hand-entered.
- `DiaryEntry`: id, foodId?, name snapshot, grams, meal
  (breakfast/lunch/dinner/snacks), day "yyyy-MM-dd", timestamp,
  nutrients snapshot, source? ("Apple Health · <app>"), externalId?
  ("hk:<UUID>").
- `WaterIntake`: day, ml, source?, externalIds? (per-day UUID registry
  so re-imports never double-count).
- `WeightEntry`: date, kg, source?, externalId?, bodyFatPercent?,
  leanMassKg?, bmi? (scale-cluster companions, e.g. HealthU+).
- `GoalProfile`: sex, age, heightCm, weightKg, activity
  (sedentary/light/moderate/active/veryActive), goal
  (lose/maintain/gain), weeklyKg 0.25–1.0, macroSplit %,
  computed targets kcal/protein/carbs/fat. Floors: 1500 kcal men,
  1200 kcal women; surplus capped +500.
- `Exercise`: id, name, muscleGroup, equipment, kind
  (weighted/bodyweight/timed/cardio). `Routine`: id, name,
  items[exerciseId, targetSets, note?].
- `WorkoutSet`: reps?, weightKg?, seconds?, distanceM?.
  `WorkoutSession`: id, routineId?, startedAt, endedAt?,
  entries[exerciseId, sets[]], notes?, source?, externalId?,
  activeEnergyKcal?, hkActivityName?. Volume = Σ reps×weightKg.
- `HealthSample`: hkUUID, typeKey (HealthDataKind raw value, e.g.
  "bodyMass"; the HK identifier string lives in `HealthDataKind.hkIdentifier`
  on the app side), start/end dates, value in canonical units
  (kg, % 0–100, count, m, kcal, g, mg, mcg, mL), sourceBundle,
  sourceName, foodName?. `HealthWorkout`: hkUUID, activityName,
  start/end, totalEnergyKcal?, sourceBundle, sourceName.
  Merge rule: match by externalId (`hk:<UUID>`); update in place,
  skip identical, add new; deletions from HealthKit remove only
  imported entries. Per-type anchors persist in UserDefaults; a lost
  anchor triggers full backfill + dedupe, never duplicates.
- `BackupFile`: schemaVersion (1), exportedAt, payload (all user data
  above + goal + settings), entry counts, FNV-1a checksum over payload.
  Import: validate → preview counts → replace or merge (match foods by
  id then barcode; diary/sessions by id; skip + report duplicates) →
  single atomic write. Pre-import snapshot saved for undo.

## Daily reference intakes (display only, not diagnosis)

Fibre 30 g; sugar free-sugars flag > 10% kcal; saturated fat < 10% kcal;
sodium < 2300 mg; potassium 3500 mg; calcium 1000 mg; iron 18 mg;
magnesium 400 mg; zinc 11 mg; vitamin A 900 mcg; vitamin C 90 mg;
vitamin D 15 mcg; B12 2.4 mcg; folate 400 mcg.
