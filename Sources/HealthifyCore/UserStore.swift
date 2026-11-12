#if canImport(Combine)
import Foundation
import Combine

/// Single on-disk document, written atomically. One file, no database.
struct UserDocument: Codable {
    var customFoods: [FoodItem] = []
    var recipes: [Recipe] = []
    var diary: [DiaryEntry] = []
    var water: [WaterIntake] = []
    var weight: [WeightEntry] = []
    var routines: [Routine] = []
    var weekPlan: [WeekPlanDay] = []
    var sessions: [WorkoutSession] = []
    var customExercises: [Exercise] = []
    var goal: GoalProfile = GoalProfile()
    var settings: AppSettings = AppSettings()
    var onboarded: Bool = false
}

/// All user state. Bundled seed data stays separate and read-only.
@MainActor
public final class UserStore: ObservableObject {
    @Published public private(set) var customFoods: [FoodItem] = []
    @Published public private(set) var recipes: [Recipe] = []
    @Published public private(set) var diary: [DiaryEntry] = []
    @Published public private(set) var water: [WaterIntake] = []
    @Published public private(set) var weight: [WeightEntry] = []
    @Published public private(set) var routines: [Routine] = []
    @Published public private(set) var weekPlan: [WeekPlanDay] = []
    @Published public private(set) var sessions: [WorkoutSession] = []
    @Published public private(set) var customExercises: [Exercise] = []
    @Published public var goal = GoalProfile()
    @Published public var settings = AppSettings()
    @Published public private(set) var onboarded = false

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        return base.appendingPathComponent("Healthify/user.json")
    }

    public init() { load() }

    // MARK: - Persistence

    private func snapshot() -> UserDocument {
        UserDocument(customFoods: customFoods, recipes: recipes, diary: diary,
                     water: water, weight: weight, routines: routines,
                     weekPlan: weekPlan,
                     sessions: sessions, customExercises: customExercises,
                     goal: goal, settings: settings, onboarded: onboarded)
    }

    private func restore(_ doc: UserDocument) {
        customFoods = doc.customFoods
        recipes = doc.recipes
        diary = doc.diary
        water = doc.water
        weight = doc.weight
        routines = doc.routines
        weekPlan = doc.weekPlan
        sessions = doc.sessions
        customExercises = doc.customExercises
        goal = doc.goal
        settings = doc.settings
        onboarded = doc.onboarded
    }

    public func save() {
        do {
            let data = try JSONEncoder().encode(snapshot())
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Local-first: a failed save must never crash the session.
            print("Healthify save failed: \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let doc = try? JSONDecoder().decode(UserDocument.self, from: data)
        else { return }
        restore(doc)
    }

    // MARK: - Food & diary

    public func addCustomFood(_ food: FoodItem) {
        customFoods.append(food); save()
    }

    public func addRecipe(_ recipe: Recipe) {
        recipes.append(recipe); save()
    }

    public func logEntry(_ entry: DiaryEntry) {
        diary.append(entry); save()
    }

    public func deleteEntry(_ entry: DiaryEntry) {
        diary.removeAll { $0.id == entry.id }; save()
    }

    /// Replace an entry after editing (nutrients already recomputed by caller).
    public func updateEntry(_ entry: DiaryEntry) {
        guard let i = diary.firstIndex(where: { $0.id == entry.id }) else { return }
        diary[i] = entry; save()
    }

    /// Quick inline quantity change: scale nutrients with grams.
    /// No-op for 0 g imports, which have no weight to scale from.
    public func adjustEntry(entry: DiaryEntry, toGrams newGrams: Double) {
        guard entry.grams > 0, newGrams > 0,
              let i = diary.firstIndex(where: { $0.id == entry.id }) else { return }
        let factor = newGrams / entry.grams
        diary[i].grams = newGrams
        diary[i].nutrients = entry.nutrients.scaled(byGrams: factor * 100)
        save()
    }

    public func setPlan(weekday: Int, routineId: UUID?, muscleLabel: String? = nil) {
        if let i = weekPlan.firstIndex(where: { $0.weekday == weekday }) {
            weekPlan[i].routineId = routineId
            weekPlan[i].muscleLabel = muscleLabel
        } else {
            weekPlan.append(WeekPlanDay(weekday: weekday, routineId: routineId,
                                        muscleLabel: muscleLabel))
        }
        save()
    }

    public func plan(forWeekday weekday: Int) -> WeekPlanDay? {
        weekPlan.first { $0.weekday == weekday }
    }

    public func entries(on day: String, meal: Meal? = nil) -> [DiaryEntry] {
        diary.filter { $0.day == day && (meal == nil || $0.meal == meal) }
            .sorted { $0.timestamp < $1.timestamp }
    }

    public func totals(on day: String) -> NutrientProfile {
        entries(on: day).reduce(NutrientProfile()) { $0 + $1.nutrients }
    }

    public func addWater(ml: Double, day: String) {
        if let i = water.firstIndex(where: { $0.day == day }) {
            water[i].ml += ml
        } else {
            water.append(WaterIntake(day: day, ml: ml))
        }
        save()
    }

    public func waterMl(on day: String) -> Double {
        water.first { $0.day == day }?.ml ?? 0
    }

    public func addWeight(kg: Double) {
        weight.append(WeightEntry(kg: kg)); save()
    }

    // MARK: - Training

    public func addRoutine(_ routine: Routine) {
        routines.append(routine); save()
    }

    public func deleteRoutine(_ routine: Routine) {
        routines.removeAll { $0.id == routine.id }; save()
    }

    public func deleteRecipe(_ recipe: Recipe) {
        recipes.removeAll { $0.id == recipe.id }; save()
    }

    public func finishSession(_ session: WorkoutSession) {
        var done = session
        done.endedAt = Date()
        sessions.append(done); save()
    }

    public func deleteSession(_ session: WorkoutSession) {
        sessions.removeAll { $0.id == session.id }; save()
    }

    public func addCustomExercise(_ exercise: Exercise) {
        customExercises.append(exercise); save()
    }

    // MARK: - Goals & settings

    public func completeOnboarding(with profile: GoalProfile) {
        goal = GoalEngine.retarget(profile)
        onboarded = true
        save()
    }

    public func updateGoal(_ profile: GoalProfile) {
        goal = GoalEngine.retarget(profile); save()
    }

    public func resetAll() {
        restore(UserDocument()); save()
    }

    public func deleteWeight(_ entry: WeightEntry) {
        weight.removeAll { $0.id == entry.id }; save()
    }

    // MARK: - Apple Health import (lossless merge; see HealthSync.swift)

    /// Merges HealthKit-mapped records, applies Health deletions, and
    /// refreshes height-driven targets. Returns a one-line user report.
    @discardableResult
    public func applyHealthImport(weights: [WeightEntry], diary: [DiaryEntry],
                                  sessions: [WorkoutSession], water: [HealthSample],
                                  height: [HealthSample],
                                  deletedUUIDs: Set<String>) -> String {
        let (w, wr) = HealthSyncMapper.mergeWeights(current: self.weight, incoming: weights)
        self.weight = w
        let (d, dr) = HealthSyncMapper.mergeDiary(current: self.diary, incoming: diary)
        self.diary = d
        let (s, sr) = HealthSyncMapper.mergeSessions(current: self.sessions, incoming: sessions)
        self.sessions = s
        let (wa, war) = HealthSyncMapper.mergeWater(current: self.water, samples: water)
        self.water = wa
        var removed = 0
        if !deletedUUIDs.isEmpty {
            let r = HealthSyncMapper.applyDeletions(
                weights: self.weight, diary: self.diary, sessions: self.sessions, hkUUIDs: deletedUUIDs)
            self.weight = r.0; self.diary = r.1; self.sessions = r.2; removed = r.3
        }
        var bits: [String] = []
        let wTotal = wr.added + wr.updated
        if wTotal > 0 { bits.append("+\(wTotal) weigh-in\(wTotal == 1 ? "" : "s")") }
        let dTotal = dr.added + dr.updated
        if dTotal > 0 { bits.append("+\(dTotal) food entr\(dTotal == 1 ? "y" : "ies")") }
        let sTotal = sr.added + sr.updated
        if sTotal > 0 { bits.append("+\(sTotal) workout\(sTotal == 1 ? "" : "s")") }
        let waTotal = war.added + war.updated
        if waTotal > 0 { bits.append("water updated \(waTotal) day\(waTotal == 1 ? "" : "s")") }
        if let h = height.max(by: { $0.endDate < $1.endDate }) {
            let cm = h.value * 100
            if abs(goal.heightCm - cm) >= 0.5 {
                goal.heightCm = cm
                goal = GoalEngine.retarget(goal)
                bits.append("height \(String(format: "%.1f", cm)) cm")
            }
        }
        save()
        if removed > 0 { bits.append("\(removed) removed in Health") }
        return bits.isEmpty ? "Already up to date." : bits.joined(separator: ", ")
    }
}
#endif
