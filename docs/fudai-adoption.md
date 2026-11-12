# Fud AI Adoption Plan — Healthify

Decision (user-confirmed): Fork Fud AI (MIT,
github.com/apoorvdarshan/fud-ai) wholesale as the new iPhone SwiftUI
base, local-only with AI/cloud/account/premium stripped. Then re-add
the Healthify essentials listed below. Nutrio is visual reference
only (Figma, no code).

## Keep from Healthify (tested, do not rewrite)
- GoalEngine: Mifflin-St Jeor, target-weight/pace direction,
  estimatedDays, 1200/1500 kcal floors, 750 kcal/day cap.
- NutrientProfile per-100g scaling, PortionMath quantity/weight,
  Atwater check, diary snapshot-at-log-time.
- SeedFoods: Indian raw materials + recipes, full micros.
- Training: weekly calendar plan, lastPerformance, suggestedWeight,
  EnergyBurn workout vs cardio split.
- UserStore + BackupCodec: local-only JSON, export/import, undo.
- HealthKit read-only sync incl. HealthU+ source dedupe.

## Adopt from Fud AI (complete code, MIT)
- SwiftUI app shell, tab structure, diary/food-log UX patterns.
- Food search + barcode flow structure, HealthKit integration patterns.
- TDEE/BMR presentation, local-first no-account onboarding shape.
- Strip out: all AI provider/coach, cloud, account, premium code.
  Healthify stays no-AI, no-login, no-network in normal use.

## Target fully-functional flows
1. First launch only: name -> Apple Health/HealthU+ sync or manual
   weight/height -> target weight + kg/week pace -> live daily kcal,
   estimated days, macros -> Home. Later launches go straight Home.
2. Home: Today Target, Actual, Remaining (bold), Workout burn,
   Cardio burn, adjusted target line.
3. Diary: clean meal timeline, date nav, inline -/+ quantity, edit,
   delete, water, collapsible micronutrients vs DailyReference.
4. Foods: search Indian + global foods/recipes, quantity or weight
   logging, add missing food/recipe, custom foods, barcode.
5. Workouts: Today-first, week strip Mon-Sun, Push/Pull/Legs seeded
   and fully editable, last-week weights + progression hint,
   add extra exercise to today, live session, volume/PR tally.
6. Settings: edit name/current/target/pace anytime (retargets kcal),
   Apple Health sync, backup export/import/reset.

## Inspected Fud AI fork (in workspace: FudAI-full/)
- Full MIT repo cloned (9,138 files). iOS app is an Xcode project
  (ios/calorietracker.xcodeproj, 209 Swift files in the app target)
  with tabs Home/Diary/Workouts/Profile, HealthKitManager, FoodStore,
  StrengthWorkoutStore, WaterStore, barcode + OpenFoodFacts/USDA
  services. It also carries Gemini/HostedAI/RevenueCat/CloudBackup
  code that the local-only, no-AI decision strips out.
- That Xcode project cannot be built or verified from this Windows
  machine, and wholesale replacement would break Healthify's working
  SwiftPM + xtool install path. So the fork stays as the reference
  base in FudAI-full/, and its shell patterns (Home-first tabs,
  diary timeline, food search + Recents, barcode, workouts) are
  adopted into the installable Healthify app, which remains the
  fully functional deliverable.

## Verification
- HealthifyCore XCTest suite must stay green.
- Preview.html mirrors adopted shell for visual approval.
- On-device: xtool install + HealthKit/HealthU+ QA checklist.
