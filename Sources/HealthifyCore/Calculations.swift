import Foundation

// MARK: - Goal engine (Mifflin-St Jeor, same family as the references)

public enum GoalEngine {
    public static let kcalPerKg = 7700.0
    public static let minKcalMale = 1500.0
    public static let minKcalFemale = 1200.0
    public static let maxDailyDelta = 750.0

    public static func bmr(sex: Sex, age: Int, heightCm: Double,
                           weightKg: Double) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        switch sex {
        case .male: return base + 5
        case .female: return base - 161
        }
    }

    public static func tdee(for p: GoalProfile) -> Double {
        bmr(sex: p.sex, age: p.age, heightCm: p.heightCm,
            weightKg: p.weightKg) * p.activity.multiplier
    }

    /// Estimated days to reach target at the chosen pace. 0 when there.
    public static func estimatedDays(currentKg: Double, targetKg: Double?,
                                     weeklyKg: Double) -> Int {
        guard let targetKg else { return 0 }
        let diff = abs(currentKg - targetKg)
        guard diff > 0.5 else { return 0 }
        let pace = min(max(weeklyKg, 0.25), 1.0)
        return Int((diff / pace * 7).rounded(.up))
    }

    /// Direction implied by a target weight. Within 0.5 kg is maintain.
    public static func direction(currentKg: Double, targetKg: Double?) -> GoalDirection {
        guard let targetKg else { return .maintain }
        if targetKg < currentKg - 0.5 { return .lose }
        if targetKg > currentKg + 0.5 { return .gain }
        return .maintain
    }

    /// Returns a copy of the profile with recomputed, safety-clamped targets.
    /// When a target weight is set it wins over the stored direction.
    public static func retarget(_ p: GoalProfile) -> GoalProfile {
        var out = p
        if p.targetWeightKg != nil {
            out.goal = direction(currentKg: p.weightKg, targetKg: p.targetWeightKg)
        }
        let tdee = tdee(for: p)
        let weekly = min(max(p.weeklyKg, 0.25), 1.0)
        let delta = min(kcalPerKg * weekly / 7.0, maxDailyDelta)
        var kcal = tdee
        switch out.goal {
        case .lose: kcal = tdee - delta
        case .gain: kcal = tdee + delta
        case .maintain: break
        }
        let floor = p.sex == .male ? minKcalMale : minKcalFemale
        if out.goal == .lose { kcal = max(kcal, floor) }
        out.targetKcal = kcal.rounded()
        let sum = max(p.proteinPct + p.carbsPct + p.fatPct, 1)
        out.proteinG = (kcal * p.proteinPct / sum / 4).rounded()
        out.carbsG = (kcal * p.carbsPct / sum / 4).rounded()
        out.fatG = (kcal * p.fatPct / sum / 9).rounded()
        return out
    }
}

// MARK: - Workout statistics (pure, testable)

public enum WorkoutStats {
    public static func bestWeightKg(exerciseId: UUID,
                                    in sessions: [WorkoutSession]) -> Double? {
        let weights = sessions.flatMap(\.entries)
            .filter { $0.exerciseId == exerciseId }
            .flatMap(\.sets)
            .compactMap(\.weightKg)
        return weights.max()
    }

    /// True when this session sets a new all-time best weight for the lift.
    public static func isPersonalRecord(session: WorkoutSession,
                                        exerciseId: UUID,
                                        priorSessions: [WorkoutSession]) -> Bool {
        let prior = bestWeightKg(exerciseId: exerciseId, in: priorSessions)
        let now = bestWeightKg(exerciseId: exerciseId, in: [session])
        guard let now else { return false }
        return now > (prior ?? 0)
    }

    /// Most recent session for a routine strictly before `date`.
    public static func previousSession(routineId: UUID?, before date: Date,
                                       in sessions: [WorkoutSession]) -> WorkoutSession? {
        sessions.filter { $0.startedAt < date && (routineId == nil || $0.routineId == routineId) }
            .sorted { $0.startedAt > $1.startedAt }.first
    }

    /// Heaviest set last time an exercise was performed before `date`.
    public static func lastPerformance(exerciseId: UUID, before date: Date,
                                       in sessions: [WorkoutSession]) -> (reps: Double, weightKg: Double, day: String)? {
        let prior = sessions.filter { $0.startedAt < date }
            .sorted { $0.startedAt > $1.startedAt }
        for s in prior {
            guard let e = s.entries.first(where: { $0.exerciseId == exerciseId }),
                  let best = e.sets.compactMap({ set -> (Double, Double)? in
                      guard let r = set.reps, let w = set.weightKg else { return nil }
                      return (r, w)
                  }).max(by: { $0.1 < $1.1 }) else { continue }
            return (best.0, best.1, s.day)
        }
        return nil
    }

    /// Simple progression: hit the rep target last time -> +2.5 kg,
    /// otherwise repeat the weight and chase reps.
    public static func suggestedWeight(lastWeightKg: Double, lastReps: Double,
                                       targetReps: Double = 10) -> Double {
        lastReps >= targetReps ? lastWeightKg + 2.5 : lastWeightKg
    }

    public static func volumeByDay(sessions: [WorkoutSession],
                                   lastDays: Int,
                                   now: Date = Date()) -> [(day: String, volume: Double)] {
        let cal = Calendar.current
        return (0..<lastDays).map { back in
            let d = cal.date(byAdding: .day, value: -back, to: now) ?? now
            let key = dayString(d)
            let vol = sessions.filter { $0.day == key }
                .reduce(0) { $0 + $1.volume }
            return (key, vol)
        }.reversed()
    }
}

// MARK: - Energy burn (Home: workout vs cardio)

/// Estimates calories burned in sessions. Recorded HealthKit energy
/// always wins; manual sessions are estimated from duration, body
/// weight and exercise kind, and flagged as estimates.
public enum EnergyBurn {
    public struct DayBurn: Hashable {
        public var workoutKcal: Double = 0
        public var cardioKcal: Double = 0
        public var hasEstimate = false
        public var total: Double { workoutKcal + cardioKcal }
    }

    private static let cardioActivities: Set<String> = [
        "Running", "Walking", "Cycling", "Swimming", "Elliptical",
        "Rowing", "Stair climbing", "Hiking", "Dance"
    ]

    private static func met(for kind: ExerciseKind) -> Double {
        switch kind {
        case .weighted: return 5.0
        case .bodyweight, .timed: return 4.0
        case .cardio: return 8.0
        }
    }

    /// kcal for one session. Uses recorded energy when present.
    public static func burn(for session: WorkoutSession, weightKg: Double,
                            kinds: [UUID: ExerciseKind]) -> DayBurn {
        var out = DayBurn()
        if let recorded = session.activeEnergyKcal {
            if let name = session.hkActivityName, cardioActivities.contains(name) {
                out.cardioKcal = recorded
            } else {
                out.workoutKcal = recorded
            }
            return out
        }
        let totalSets = max(session.entries.reduce(0) { $0 + $1.sets.count }, 1)
        let minutes: Double
        if let end = session.endedAt, end > session.startedAt {
            minutes = end.timeIntervalSince(session.startedAt) / 60
        } else {
            minutes = Double(totalSets) * 3 // fallback: ~3 min per set
        }
        let hours = minutes / 60
        for entry in session.entries {
            let kind = kinds[entry.exerciseId] ?? .weighted
            let share = Double(entry.sets.count) / Double(totalSets)
            let kcal = met(for: kind) * weightKg * hours * share
            if kind == .cardio { out.cardioKcal += kcal } else { out.workoutKcal += kcal }
        }
        out.hasEstimate = true
        return out
    }

    /// Burn for one calendar day only.
    public static func todayBurn(sessions: [WorkoutSession], day: String,
                                 weightKg: Double,
                                 kinds: [UUID: ExerciseKind]) -> DayBurn {
        sessions.filter { $0.day == day }.reduce(DayBurn()) { acc, s in
            let b = burn(for: s, weightKg: weightKg, kinds: kinds)
            var o = acc
            o.workoutKcal += b.workoutKcal
            o.cardioKcal += b.cardioKcal
            o.hasEstimate = o.hasEstimate || b.hasEstimate
            return o
        }
    }
}

/// Foods logged most recently, for one-tap re-logging (Fud/MFP staple).
public enum RecentFoods {
    public static func recentFoodIds(in diary: [DiaryEntry], limit: Int = 8) -> [UUID] {
        var seen = Set<UUID>(); var out: [UUID] = []
        for e in diary.sorted(by: { $0.timestamp > $1.timestamp }) {
            guard let id = e.foodId, !seen.contains(id) else { continue }
            seen.insert(id); out.append(id)
            if out.count >= max(limit, 0) { break }
        }
        return out
    }
}

// MARK: - Daily reference intakes (display only, never diagnosis)

public struct MicroRef: Identifiable {
    public var id: String { label }
    public var label: String
    public var unit: String
    public var daily: Double
    public var get: (NutrientProfile) -> Double
}

public struct DailyReference {
    public static let micros: [MicroRef] = [
        MicroRef(label: "Fibre", unit: "g", daily: 30, get: \.fiberG),
        MicroRef(label: "Sodium", unit: "mg", daily: 2300, get: \.sodiumMg),
        MicroRef(label: "Potassium", unit: "mg", daily: 3500, get: \.potassiumMg),
        MicroRef(label: "Calcium", unit: "mg", daily: 1000, get: \.calciumMg),
        MicroRef(label: "Iron", unit: "mg", daily: 18, get: \.ironMg),
        MicroRef(label: "Magnesium", unit: "mg", daily: 400, get: \.magnesiumMg),
        MicroRef(label: "Zinc", unit: "mg", daily: 11, get: \.zincMg),
        MicroRef(label: "Vitamin A", unit: "mcg", daily: 900, get: \.vitAMcg),
        MicroRef(label: "Vitamin C", unit: "mg", daily: 90, get: \.vitCMg),
        MicroRef(label: "Vitamin D", unit: "mcg", daily: 15, get: \.vitDMcg),
        MicroRef(label: "Vitamin B12", unit: "mcg", daily: 2.4, get: \.vitB12Mcg),
        MicroRef(label: "Folate", unit: "mcg", daily: 400, get: \.folateMcg),
    ]
}
