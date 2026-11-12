# Evidence ledger

Every claim below is marked **observed** (seen directly this session),
**inferred** (reasonable reading of public material), or **unknown**
(not verifiable without the app/binary). No HealthifyMe or MyFitnessPal
code, text, images, or food data were copied; URLs are sources only.

## HealthifyMe — observed (via site + App Store listing)

- OBSERVED: Product is now branded "Healthify", developer
  "HealthifyMe Wellness Private Limited", 40M+ users claimed,
  rating ~4.6. Source: App Store listing
  `https://apps.apple.com/in/app/healthify-ai-calorie-tracker/id943712366`.
- OBSERVED: Core pitch is AI-first: "HealthifySnap" photo meal logging,
  "Auto Snap" background logging, "Ria" AI coach, photo/voice logging.
  Source: `https://www.healthifyme.com/in/`.
- OBSERVED: Tracks calories plus protein, fats, carbs, fibre, water,
  sleep, weight, workouts/activity. Source: App Store listing.
- OBSERVED: Human coaching upsell ("HealthifyPro") exists alongside AI.
  Source: `https://www.healthifyme.com/in/`.

## MyFitnessPal — observed

- OBSERVED: Claims 280M users, 18M+ global foods, barcode scan, Meal Scan,
  Voice Log, AI Nutrition Coach, macro/micro/vitamin tracking, water,
  weight, exercise, steps, intermittent fasting. Source:
  `https://www.myfitnesspal.com/`.
- OBSERVED: Free tier = food search + basic tracking; Barcode Scan,
  fasting tracker, custom macro goals are Premium. 7-day trial, monthly/
  annual billing. Source: `https://www.myfitnesspal.com/` FAQ section.
- OBSERVED: Goal engine uses Mifflin-St Jeor BMR + activity level, ±500
  kcal per ~0.45 kg/week, BMI floor on targets. Source: same FAQ.

## Inferred (competitor behaviour, not API truth)

- INFERRED: Both gate advanced logging (barcode/AI) and custom macro
  goals behind paywalls; free tier is search + diary + targets.
- INFERRED: HealthifyMe's Indian-food coverage is its differentiator vs
  MyFitnessPal's breadth. Our MVP answers with a bundled curated
  Indian-food set, not with AI.

## Unknown (blocked without a legal binary + REA session)

- UNKNOWN: Exact screen flows, health-score formula, Ria/coach internals,
  database schema, sync protocol, pricing entitlements enforcement.
- None of the above is needed: our requirements are designed, not
  extracted. If an IPA is supplied later, inventory it via REA
  (`open_binary` route) and record findings here before changing scope.
