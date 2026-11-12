import XCTest
@testable import HealthifyCore

final class CoreTests: XCTestCase {

    private func baseProfile() -> GoalProfile {
        GoalProfile(sex: .female, age: 30, heightCm: 165, weightKg: 65,
                    activity: .moderate, goal: .maintain, weeklyKg: 0.5,
                    proteinPct: 25, carbsPct: 45, fatPct: 30)
    }

    func testMaintainEqualsTDEE() {
        let p = baseProfile()
        let out = GoalEngine.retarget(p)
        XCTAssertEqual(out.targetKcal, GoalEngine.tdee(for: p).rounded())
    }

    func testLoseRespectsFloor() {
        var p = baseProfile()
        p.sex = .female
        p.weightKg = 45
        p.heightCm = 150
        p.activity = .sedentary
        p.goal = .lose
        p.weeklyKg = 1.0
        let out = GoalEngine.retarget(p)
        XCTAssertGreaterThanOrEqual(out.targetKcal, GoalEngine.minKcalFemale)
    }

    func testMacroCaloriesMatchTarget() {
        var p = baseProfile()
        p.goal = .lose
        let out = GoalEngine.retarget(p)
        let fromMacros = out.proteinG * 4 + out.carbsG * 4 + out.fatG * 9
        XCTAssertLessThanOrEqual(abs(fromMacros - out.targetKcal), 12)
    }

    func testSeedDataPassesAtwater() {
        for food in seedFoods {
            XCTAssertTrue(food.nutrientsPer100g.atwaterOK(),
                          "\(food.name) fails Atwater check")
        }
    }

    func testScalingDoublesAt200g() {
        var n = NutrientProfile()
        n.kcal = 100
        n.proteinG = 10
        let scaled = n.scaled(byGrams: 200)
        XCTAssertEqual(scaled.kcal, 200)
        XCTAssertEqual(scaled.proteinG, 20)
    }

    private func sampleBody() -> BackupBody {
        var b = BackupBody()
        var n = NutrientProfile()
        n.kcal = 105
        n.proteinG = 1
        b.diary = [DiaryEntry(name: "Banana", grams: 120, meal: .snacks,
                              day: "2026-11-12", nutrients: n)]
        b.weight = [WeightEntry(kg: 65)]
        b.water = [WaterIntake(day: "2026-11-12", ml: 500)]
        b.goal = baseProfile()
        return b
    }

    func testBackupRoundTrip() throws {
        let data = try BackupCodec.encode(sampleBody())
        let file = try BackupCodec.validate(data)
        XCTAssertEqual(file.schemaVersion, 1)
        XCTAssertEqual(file.counts["diary"], 1)
        XCTAssertEqual(file.body.diary.first?.name, "Banana")
    }

    func testTamperedBackupRejected() throws {
        let data = try BackupCodec.encode(sampleBody())
        var file = try BackupCodec.validate(data)
        var n = NutrientProfile()
        n.kcal = 9999
        file.body.diary.append(DiaryEntry(name: "Evil", grams: 1, meal: .snacks,
                                          day: "2026-11-12", nutrients: n))
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let tampered = try enc.encode(file)
        XCTAssertThrowsError(try BackupCodec.validate(tampered)) { error in
            guard case BackupError.checksumMismatch = error else {
                return XCTFail("expected checksumMismatch, got \(error)")
            }
        }
    }

    func testMergeSkipsDuplicates() throws {
        let body = sampleBody()
        let (once, _) = BackupCodec.merge(current: BackupBody(), incoming: body)
        let (twice, report) = BackupCodec.merge(current: once, incoming: body)
        XCTAssertEqual(twice.diary.count, 1)
        XCTAssertTrue(report.joined().contains("0 added"))
    }

    func testVolumeAndPersonalRecord() {
        let ex = seedExercises[0].id
        let old = WorkoutSession(entries: [
            SessionEntry(exerciseId: ex, sets: [WorkoutSet(reps: 5, weightKg: 60)])])
        XCTAssertEqual(old.volume, 300)
        XCTAssertEqual(WorkoutStats.bestWeightKg(exerciseId: ex, in: [old]), 60)
        let better = WorkoutSession(entries: [
            SessionEntry(exerciseId: ex, sets: [WorkoutSet(reps: 5, weightKg: 62.5)])])
        XCTAssertTrue(WorkoutStats.isPersonalRecord(session: better,
                                                    exerciseId: ex,
                                                    priorSessions: [old]))
        XCTAssertFalse(WorkoutStats.isPersonalRecord(session: old,
                                                     exerciseId: ex,
                                                     priorSessions: [better]))
    }

    func testPortionUnits() {
        let rice = seedFoods.first { $0.name == "Cooked white rice" }!
        let milk = seedFoods.first { $0.name == "Milk, toned" }!
        let roti = seedFoods.first { $0.name == "Whole wheat roti" }!
        // Weight and volume resolve to grams.
        XCTAssertEqual(PortionMath.grams(amount: 1, unit: "cup", food: rice), 150)
        XCTAssertEqual(PortionMath.grams(amount: 2, unit: "glass", food: milk), 500)
        XCTAssertEqual(PortionMath.grams(amount: 100, unit: "g", food: rice), 100)
        XCTAssertEqual(PortionMath.grams(amount: 2, unit: "serving", food: roti), 80)
        // Unknown units and zero amounts resolve to nil, never to 0 g silently.
        XCTAssertNil(PortionMath.grams(amount: 1, unit: "ladle", food: rice))
        XCTAssertNil(PortionMath.grams(amount: 0, unit: "g", food: rice))
    }

    func testRecipePerServing() {
        let lookup = Dictionary(uniqueKeysWithValues: seedFoods.map { ($0.id, $0) })
        let dal = seedFoods.first { $0.name.hasPrefix("Toor dal") }!
        let rice = seedFoods.first { $0.name == "Cooked white rice" }!
        let recipe = Recipe(name: "Dal rice", servings: 2, ingredients: [
            RecipeIngredient(foodId: dal.id, grams: 150),
            RecipeIngredient(foodId: rice.id, grams: 150)
        ])
        let per = recipe.nutrientsPerServing(lookup: lookup)
        // 150 g dal (180 kcal, 10.5 g protein) +
        // 150 g rice (195 kcal, 4.05 g protein), halved.
        XCTAssertEqual(per.kcal, 187.5, accuracy: 0.01)
        XCTAssertEqual(per.proteinG, 7.275, accuracy: 0.01)
    }

    // MARK: - HealthSync (Apple Health incl. HealthU+ scale path)

    private func hkSample(_ type: HealthDataKind, value: Double,
                          when: Double, uuid: String = UUID().uuidString) -> HealthSample {
        HealthSample(hkUUID: uuid, typeKey: type.rawValue,
                     startDate: Date(timeIntervalSince1970: when),
                     endDate: Date(timeIntervalSince1970: when),
                     value: value, sourceBundle: "com.lefuhealthu.app",
                     sourceName: "HealthU+")
    }

    private func atHour(_ h: Int) -> Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = h; c.minute = 0
        return Calendar.current.date(from: c)!
    }

    func testNutrientMapping() {
        let p = HealthSyncMapper.nutrients(typeKey: HealthDataKind.dietaryProtein.rawValue, value: 10)!
        XCTAssertEqual(p.proteinG, 10)
        XCTAssertEqual(p.kcal, 0)
        let na = HealthSyncMapper.nutrients(typeKey: HealthDataKind.dietarySodium.rawValue, value: 500)!
        XCTAssertEqual(na.sodiumMg, 500)
        XCTAssertNil(HealthSyncMapper.nutrients(typeKey: HealthDataKind.dietaryWater.rawValue, value: 250))
        XCTAssertNil(HealthSyncMapper.nutrients(typeKey: HealthDataKind.workout.rawValue, value: 1))
    }

    func testMealInference() {
        XCTAssertEqual(HealthSyncMapper.meal(for: atHour(8)), .breakfast)
        XCTAssertEqual(HealthSyncMapper.meal(for: atHour(12)), .lunch)
        XCTAssertEqual(HealthSyncMapper.meal(for: atHour(16)), .snacks)
        XCTAssertEqual(HealthSyncMapper.meal(for: atHour(20)), .dinner)
        XCTAssertEqual(HealthSyncMapper.meal(for: atHour(2)), .snacks)
    }

    func testWeightJoinScaleCluster() {
        let t = 1_700_000_000.0
        let entries = HealthSyncMapper.weightEntries(
            bodyMass: [hkSample(.bodyMass, value: 72.5, when: t)],
            bodyFat: [hkSample(.bodyFatPercentage, value: 24.5, when: t + 60)],
            leanMass: [hkSample(.leanBodyMass, value: 50.0, when: t + 120)],
            bmi: [hkSample(.bodyMassIndex, value: 23.1, when: t - 300)])
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].kg, 72.5)
        XCTAssertEqual(entries[0].bodyFatPercent, 24.5)
        XCTAssertEqual(entries[0].leanMassKg, 50.0)
        XCTAssertEqual(entries[0].bmi, 23.1)
        XCTAssertEqual(entries[0].source, "Apple Health · HealthU+")
        // A fat reading an hour away belongs to another moment.
        let far = HealthSyncMapper.weightEntries(
            bodyMass: [hkSample(.bodyMass, value: 72.5, when: t)],
            bodyFat: [hkSample(.bodyFatPercentage, value: 24.5, when: t + 3600)])
        XCTAssertNil(far[0].bodyFatPercent)
    }

    func testMergeDedupeAndUpdate() {
        let w = WeightEntry(kg: 72.5, source: "Apple Health · HealthU+",
                            externalId: "hk:AAA")
        var (out, r) = HealthSyncMapper.mergeWeights(current: [], incoming: [w])
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(r.added, 1)
        XCTAssertEqual(r.skipped, 0)
        // Same UUID again: no duplicate.
        let (out2, r2) = HealthSyncMapper.mergeWeights(current: out, incoming: [w])
        XCTAssertEqual(out2.count, 1)
        XCTAssertEqual(r2.skipped, 1)
        // Corrected value, same UUID: updated in place.
        var fixed = w; fixed.kg = 72.4
        let (out3, r3) = HealthSyncMapper.mergeWeights(current: out2, incoming: [fixed])
        XCTAssertEqual(out3.count, 1)
        XCTAssertEqual(r3.updated, 1)
        XCTAssertEqual(out3[0].kg, 72.4)
        // Manual entries (no external id) are never deduped away.
        let manual = WeightEntry(kg: 72.5)
        let (out4, r4) = HealthSyncMapper.mergeWeights(current: out3, incoming: [manual])
        XCTAssertEqual(out4.count, 2)
        XCTAssertEqual(r4.added, 1)
    }

    func testDiaryMergePreservesExistingAndDedupes() {
        // Regression: the store must merge incoming imports into the
        // existing diary, never replace the diary with the imports.
        let manual = DiaryEntry(name: "Home dal", grams: 200, meal: .lunch,
                                day: "2026-11-12", nutrients: NutrientProfile())
        let imported = DiaryEntry(name: "Rice · HealthU+", grams: 0, meal: .dinner,
                                  day: "2026-11-12", nutrients: NutrientProfile(),
                                  source: "Apple Health · HealthU+",
                                  externalId: "hk:BBB")
        let (out, r) = HealthSyncMapper.mergeDiary(current: [manual], incoming: [imported])
        XCTAssertEqual(out.count, 2)
        XCTAssertEqual(r.added, 1)
        XCTAssertTrue(out.contains(where: { $0.externalId == nil }))
        // Re-sync: nothing new, nothing duplicated.
        let (out2, r2) = HealthSyncMapper.mergeDiary(current: out, incoming: [imported])
        XCTAssertEqual(out2.count, 2)
        XCTAssertEqual(r2.skipped, 1)
    }

    func testSessionMergePreservesExistingAndDedupes() {
        let manual = WorkoutSession(routineName: "Morning lift",
                                    startedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let imported = WorkoutSession(routineName: "Running",
                                      startedAt: Date(timeIntervalSince1970: 1_700_001_000),
                                      notes: "Imported from Apple Health (HealthU+)",
                                      source: "Apple Health · HealthU+",
                                      externalId: "hk:CCC")
        let (out, r) = HealthSyncMapper.mergeSessions(current: [manual], incoming: [imported])
        XCTAssertEqual(out.count, 2)
        XCTAssertEqual(r.added, 1)
        let (out2, r2) = HealthSyncMapper.mergeSessions(current: out, incoming: [imported])
        XCTAssertEqual(out2.count, 2)
        XCTAssertEqual(r2.skipped, 1)
    }

    func testDeletionsOnlyTouchImports() {
        let imported = WeightEntry(kg: 72.5, source: "Apple Health · HealthU+",
                                   externalId: "hk:AAA")
        let manual = WeightEntry(kg: 72.5)
        let diary = [DiaryEntry(name: "Rice", grams: 100, meal: .lunch,
                                day: "2026-01-01", nutrients: NutrientProfile(),
                                source: "Apple Health · X", externalId: "hk:BBB")]
        let (w, d, _, removed) = HealthSyncMapper.applyDeletions(
            weights: [imported, manual], diary: diary, sessions: [],
            hkUUIDs: ["AAA", "BBB"])
        XCTAssertEqual(removed, 2)
        XCTAssertEqual(w.count, 1)
        XCTAssertNil(w[0].externalId) // the manual one survives
        XCTAssertTrue(d.isEmpty)
    }

    func testWaterUnionNeverDoubleCounts() {
        // Noon UTC: both samples land on the same local day in ±12h zones.
        let noon = 1_699_963_200.0
        let day = dayString(Date(timeIntervalSince1970: noon))
        let manual = WaterIntake(day: day, ml: 250)
        let a = hkSample(.dietaryWater, value: 500, when: noon, uuid: "A")
        let b = hkSample(.dietaryWater, value: 250, when: noon + 100, uuid: "B")
        let (out1, _) = HealthSyncMapper.mergeWater(current: [manual], samples: [a])
        XCTAssertEqual(out1[0].ml, 750)
        let (out2, r2) = HealthSyncMapper.mergeWater(current: out1, samples: [a, b])
        XCTAssertEqual(out2[0].ml, 1000)
        XCTAssertEqual(r2.updated, 1)
        let (out3, r3) = HealthSyncMapper.mergeWater(current: out2, samples: [a, b])
        XCTAssertEqual(out3[0].ml, 1000)
        XCTAssertEqual(r3.skipped, 1)
    }

    func testLegacyBackupsStillDecode() throws {
        // Old files lack the new provenance keys entirely.
        let wJSON = "{\"id\":\"\(UUID().uuidString)\",\"date\":1700000000,\"kg\":70}".data(using: .utf8)!
        let w = try JSONDecoder().decode(WeightEntry.self, from: wJSON)
        XCTAssertEqual(w.kg, 70)
        XCTAssertNil(w.source)
        XCTAssertNil(w.externalId)
        let hJSON = "{\"day\":\"2026-01-01\",\"ml\":250}".data(using: .utf8)!
        let h = try JSONDecoder().decode(WaterIntake.self, from: hJSON)
        XCTAssertEqual(h.ml, 250)
        XCTAssertNil(h.externalIds)
    }

    func testTargetWeightDirection() {
        XCTAssertEqual(GoalEngine.direction(currentKg: 72.5, targetKg: 65), .lose)
        XCTAssertEqual(GoalEngine.direction(currentKg: 65, targetKg: 72.5), .gain)
        XCTAssertEqual(GoalEngine.direction(currentKg: 70, targetKg: 70.2), .maintain)
        XCTAssertEqual(GoalEngine.direction(currentKg: 70, targetKg: nil), .maintain)
        // Target below current must produce a deficit even if stored goal says gain.
        var p = baseProfile()
        p.weightKg = 80; p.targetWeightKg = 70; p.goal = .gain; p.weeklyKg = 0.5
        let out = GoalEngine.retarget(p)
        XCTAssertEqual(out.goal, .lose)
        XCTAssertLessThan(out.targetKcal, GoalEngine.tdee(for: p))
        // Old profiles without the new fields still retarget as before.
        var legacy = baseProfile()
        legacy.targetWeightKg = nil; legacy.displayName = nil; legacy.goal = .maintain
        XCTAssertEqual(GoalEngine.retarget(legacy).targetKcal,
                       GoalEngine.tdee(for: legacy).rounded())
    }

    func testBurnPrefersRecordedAndSplitsKinds() {
        let start = Date()
        let hkRun = WorkoutSession(routineName: "Running", startedAt: start,
                                   endedAt: start.addingTimeInterval(1800),
                                   source: "Apple Health · X", externalId: "hk:1",
                                   activeEnergyKcal: 300, hkActivityName: "Running")
        let recorded = EnergyBurn.burn(for: hkRun, weightKg: 70, kinds: [:])
        XCTAssertEqual(recorded.cardioKcal, 300)
        XCTAssertEqual(recorded.workoutKcal, 0)
        XCTAssertFalse(recorded.hasEstimate)
        // Manual 60-min strength session at 70 kg: 5 MET * 70 * 1h = 350.
        let ex = seedExercises[0].id
        let manual = WorkoutSession(routineName: "Lift", startedAt: start,
                                    endedAt: start.addingTimeInterval(3600),
                                    entries: [SessionEntry(exerciseId: ex,
                                                           sets: [WorkoutSet(reps: 5, weightKg: 60)])])
        let est = EnergyBurn.burn(for: manual, weightKg: 70, kinds: [ex: .weighted])
        XCTAssertEqual(est.workoutKcal, 350, accuracy: 0.01)
        XCTAssertTrue(est.hasEstimate)
        // Other-day sessions never count toward today.
        let today = EnergyBurn.todayBurn(sessions: [hkRun, manual], day: "1900-01-01",
                                         weightKg: 70, kinds: [ex: .weighted])
        XCTAssertEqual(today.total, 0)
    }

    func testEstimatedDaysAndSeedCompleteness() {
        XCTAssertEqual(GoalEngine.estimatedDays(currentKg: 72.5, targetKg: 65, weeklyKg: 0.5), 105)
        XCTAssertEqual(GoalEngine.estimatedDays(currentKg: 70, targetKg: 70.2, weeklyKg: 0.5), 0)
        XCTAssertEqual(GoalEngine.estimatedDays(currentKg: 70, targetKg: nil, weeklyKg: 0.5), 0)
        XCTAssertGreaterThanOrEqual(seedFoods.count, 50)
        for food in seedFoods {
            XCTAssertTrue(food.nutrientsPer100g.atwaterOK(), "\(food.name) Atwater")
            XCTAssertGreaterThan(food.nutrientsPer100g.kcal, 0, food.name)
            XCTAssertFalse(food.units?.isEmpty ?? true, "\(food.name) needs a quantity unit")
            XCTAssertGreaterThan(food.servingGrams, 0, food.name)
        }
        // Egg by quantity: 2 pieces = 100 g = 155 kcal, 13 g protein per 100 g scaled.
        let egg = seedFoods.first { $0.name == "Egg, boiled" }!
        XCTAssertEqual(PortionMath.grams(amount: 2, unit: "piece", food: egg), 100)
        let two = egg.nutrientsPer100g.scaled(byGrams: 100)
        XCTAssertEqual(two.kcal, 155, accuracy: 0.01)
        XCTAssertEqual(two.proteinG, 13, accuracy: 0.01)
    }

    func testLastPerformanceLookup() {
        let ex = seedExercises[0].id
        let lastWeek = WorkoutSession(startedAt: Date().addingTimeInterval(-7 * 86400),
                                      entries: [SessionEntry(exerciseId: ex, sets: [WorkoutSet(reps: 8, weightKg: 60), WorkoutSet(reps: 6, weightKg: 65)])])
        let older = WorkoutSession(startedAt: Date().addingTimeInterval(-14 * 86400),
                                   entries: [SessionEntry(exerciseId: ex, sets: [WorkoutSet(reps: 8, weightKg: 55)])])
        let p = WorkoutStats.lastPerformance(exerciseId: ex, before: Date(), in: [older, lastWeek])
        XCTAssertEqual(p?.weightKg, 65)
        XCTAssertEqual(p?.reps, 6)
        XCTAssertNil(WorkoutStats.lastPerformance(exerciseId: UUID(), before: Date(), in: [lastWeek]))
    }

    func testSeedRecipesAndProgression() {
        let recipes = seedRecipes()
        XCTAssertGreaterThanOrEqual(recipes.count, 8)
        let lookup = Dictionary(uniqueKeysWithValues: seedFoods.map { ($0.id, $0) })
        for r in recipes {
            XCTAssertFalse(r.ingredients.isEmpty, r.name)
            XCTAssertGreaterThan(r.nutrientsPerServing(lookup: lookup).kcal, 0, r.name)
        }
        XCTAssertGreaterThanOrEqual(seedFoods.count, 85)
        XCTAssertEqual(WorkoutStats.suggestedWeight(lastWeightKg: 60, lastReps: 10), 62.5)
        XCTAssertEqual(WorkoutStats.suggestedWeight(lastWeightKg: 60, lastReps: 6), 60)
        XCTAssertGreaterThanOrEqual(seedExercises.count, 30)
        XCTAssertGreaterThanOrEqual(seedRoutines(exercises: seedExercises).count, 6)
    }

    func testRecentFoodsFromDiary() {
        let a = seedFoods[0].id, b = seedFoods[1].id
        func e(_ id: UUID, _ name: String, _ t: Double) -> DiaryEntry {
            DiaryEntry(foodId: id, name: name, grams: 100, meal: .lunch,
                       day: "2026-11-12", timestamp: Date(timeIntervalSince1970: t),
                       nutrients: NutrientProfile())
        }
        let diary = [e(a, "A", 100), e(b, "B", 200), e(a, "A", 300),
                     DiaryEntry(name: "Manual", grams: 50, meal: .snacks,
                                day: "2026-11-12", timestamp: Date(timeIntervalSince1970: 400),
                                nutrients: NutrientProfile())]
        // Most recent first, deduped, manual (no foodId) entries excluded.
        XCTAssertEqual(RecentFoods.recentFoodIds(in: diary, limit: 10), [a, b])
        XCTAssertEqual(RecentFoods.recentFoodIds(in: diary, limit: 1), [a])
        XCTAssertTrue(RecentFoods.recentFoodIds(in: [], limit: 5).isEmpty)
    }

    func testHealthUPlusEndToEnd() {
        // One scale moment: weight + fat + lean + BMI from HealthU+.
        let t = 1_700_000_000.0
        let entries = HealthSyncMapper.weightEntries(
            bodyMass: [hkSample(.bodyMass, value: 72.5, when: t)],
            bodyFat: [hkSample(.bodyFatPercentage, value: 24.5, when: t + 30)],
            leanMass: [hkSample(.leanBodyMass, value: 50.2, when: t + 45)],
            bmi: [hkSample(.bodyMassIndex, value: 23.1, when: t + 50)])
        let manual = [WeightEntry(date: Date(timeIntervalSince1970: t - 86400), kg: 73.0)]
        let (merged, r) = HealthSyncMapper.mergeWeights(current: manual, incoming: entries)
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(r.added, 1)
        // Sync again: nothing new, nothing duplicated.
        let (merged2, r2) = HealthSyncMapper.mergeWeights(current: merged, incoming: entries)
        XCTAssertEqual(merged2.count, 2)
        XCTAssertEqual(r2.skipped, 1)
    }
}
