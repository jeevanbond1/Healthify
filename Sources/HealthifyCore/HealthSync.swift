import Foundation

// MARK: - Apple Health import (read-only)
//
// Every data point is preserved: incremental reads use per-type anchors,
// every imported record carries its HealthKit UUID, and re-imports are
// deduplicated — never duplicated, never silently dropped. HealthU+
// (Lefu scale app) writes weight, body fat %, lean mass and BMI straight
// into Apple Health, so its readings arrive here with no extra work.

// Canonical units used by HealthSample.value:
// kg, percent (0-100), count, m, kcal, g, mg, mcg, mL.
public enum HealthDataGroup: String, Codable, CaseIterable {
    case body, nutrition, activity
}

public enum HealthDataKind: String, Codable, CaseIterable {
    // Body & scale (incl. HealthU+ readings)
    case bodyMass
    case bodyFatPercentage
    case leanBodyMass
    case bodyMassIndex
    case height
    // Nutrition
    case dietaryEnergy
    case dietaryProtein
    case dietaryCarbs
    case dietaryFat
    case dietaryFiber
    case dietarySugar
    case dietarySodium
    case dietaryPotassium
    case dietaryCalcium
    case dietaryIron
    case dietaryVitaminC
    case dietaryWater
    // Activity
    case workout

    /// Exact HKObjectType identifier string (HKQuantityTypeIdentifier…).
    public var hkIdentifier: String {
        switch self {
        case .bodyMass: return "HKQuantityTypeIdentifierBodyMass"
        case .bodyFatPercentage: return "HKQuantityTypeIdentifierBodyFatPercentage"
        case .leanBodyMass: return "HKQuantityTypeIdentifierLeanBodyMass"
        case .bodyMassIndex: return "HKQuantityTypeIdentifierBodyMassIndex"
        case .height: return "HKQuantityTypeIdentifierHeight"
        case .dietaryEnergy: return "HKQuantityTypeIdentifierDietaryEnergyConsumed"
        case .dietaryProtein: return "HKQuantityTypeIdentifierDietaryProtein"
        case .dietaryCarbs: return "HKQuantityTypeIdentifierDietaryCarbohydrates"
        case .dietaryFat: return "HKQuantityTypeIdentifierDietaryFatTotal"
        case .dietaryFiber: return "HKQuantityTypeIdentifierDietaryFiber"
        case .dietarySugar: return "HKQuantityTypeIdentifierDietarySugar"
        case .dietarySodium: return "HKQuantityTypeIdentifierDietarySodium"
        case .dietaryPotassium: return "HKQuantityTypeIdentifierDietaryPotassium"
        case .dietaryCalcium: return "HKQuantityTypeIdentifierDietaryCalcium"
        case .dietaryIron: return "HKQuantityTypeIdentifierDietaryIron"
        case .dietaryVitaminC: return "HKQuantityTypeIdentifierDietaryVitaminC"
        case .dietaryWater: return "HKQuantityTypeIdentifierDietaryWater"
        case .workout: return "HKWorkoutTypeIdentifier"
        }
    }

    public var group: HealthDataGroup {
        switch self {
        case .bodyMass, .bodyFatPercentage, .leanBodyMass, .bodyMassIndex, .height:
            return .body
        case .dietaryEnergy, .dietaryProtein, .dietaryCarbs, .dietaryFat,
             .dietaryFiber, .dietarySugar, .dietarySodium, .dietaryPotassium,
             .dietaryCalcium, .dietaryIron, .dietaryVitaminC, .dietaryWater:
            return .nutrition
        case .workout:
            return .activity
        }
    }

    public var displayName: String {
        switch self {
        case .bodyMass: return "Weight"
        case .bodyFatPercentage: return "Body fat"
        case .leanBodyMass: return "Lean body mass"
        case .bodyMassIndex: return "BMI"
        case .height: return "Height"
        case .dietaryEnergy: return "Energy eaten"
        case .dietaryProtein: return "Protein eaten"
        case .dietaryCarbs: return "Carbs eaten"
        case .dietaryFat: return "Fat eaten"
        case .dietaryFiber: return "Fibre eaten"
        case .dietarySugar: return "Sugar eaten"
        case .dietarySodium: return "Sodium eaten"
        case .dietaryPotassium: return "Potassium eaten"
        case .dietaryCalcium: return "Calcium eaten"
        case .dietaryIron: return "Iron eaten"
        case .dietaryVitaminC: return "Vitamin C eaten"
        case .dietaryWater: return "Water"
        case .workout: return "Workouts"
        }
    }
}

/// One HealthKit quantity sample, already converted to canonical units.
/// Pure data — no HealthKit import, so this file stays Linux-testable.
public struct HealthSample: Codable, Hashable {
    public var hkUUID: String
    public var typeKey: String
    public var startDate: Date
    public var endDate: Date
    public var value: Double
    public var sourceBundle: String
    public var sourceName: String
    /// Optional food label from sample metadata, if the writer set one.
    public var foodName: String?

    public init(hkUUID: String, typeKey: String, startDate: Date,
                endDate: Date, value: Double, sourceBundle: String,
                sourceName: String, foodName: String? = nil) {
        self.hkUUID = hkUUID
        self.typeKey = typeKey
        self.startDate = startDate
        self.endDate = endDate
        self.value = value
        self.sourceBundle = sourceBundle
        self.sourceName = sourceName
        self.foodName = foodName
    }

    public var externalId: String { "hk:\(hkUUID)" }
}

/// One HealthKit workout, already mapped to plain data.
public struct HealthWorkout: Codable, Hashable {
    public var hkUUID: String
    public var activityName: String
    public var startDate: Date
    public var endDate: Date
    public var totalEnergyKcal: Double?
    public var sourceBundle: String
    public var sourceName: String

    public init(hkUUID: String, activityName: String, startDate: Date,
                endDate: Date, totalEnergyKcal: Double? = nil,
                sourceBundle: String, sourceName: String) {
        self.hkUUID = hkUUID
        self.activityName = activityName
        self.startDate = startDate
        self.endDate = endDate
        self.totalEnergyKcal = totalEnergyKcal
        self.sourceBundle = sourceBundle
        self.sourceName = sourceName
    }

    public var externalId: String { "hk:\(hkUUID)" }
}

// MARK: - Mapping (pure, unit-tested)

public enum HealthSyncMapper {
    /// Single-nutrient profile for one dietary sample (canonical units).
    /// Returns nil for non-nutrient kinds.
    public static func nutrients(typeKey: String, value: Double) -> NutrientProfile? {
        var n = NutrientProfile()
        switch typeKey {
        case HealthDataKind.dietaryEnergy.rawValue: n.kcal = value
        case HealthDataKind.dietaryProtein.rawValue: n.proteinG = value
        case HealthDataKind.dietaryCarbs.rawValue: n.carbsG = value
        case HealthDataKind.dietaryFat.rawValue: n.fatG = value
        case HealthDataKind.dietaryFiber.rawValue: n.fiberG = value
        case HealthDataKind.dietarySugar.rawValue: n.sugarG = value
        case HealthDataKind.dietarySodium.rawValue: n.sodiumMg = value
        case HealthDataKind.dietaryPotassium.rawValue: n.potassiumMg = value
        case HealthDataKind.dietaryCalcium.rawValue: n.calciumMg = value
        case HealthDataKind.dietaryIron.rawValue: n.ironMg = value
        case HealthDataKind.dietaryVitaminC.rawValue: n.vitCMg = value
        default: return nil
        }
        return n
    }

    /// Meal bucket from sample end time. Documented, deterministic.
    public static func meal(for date: Date) -> Meal {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<10: return .breakfast
        case 10..<15: return .lunch
        case 15..<17: return .snacks
        case 17..<22: return .dinner
        default: return .snacks
        }
    }

    /// One diary entry per dietary sample. Nothing is aggregated away.
    public static func diaryEntries(from samples: [HealthSample]) -> [DiaryEntry] {
        samples.compactMap { s in
            guard let n = nutrients(typeKey: s.typeKey, value: s.value) else { return nil }
            let name = (s.foodName?.isEmpty == false ? s.foodName! : "Logged food")
                + " · \(s.sourceName)"
            return DiaryEntry(
                name: name, grams: 0, meal: meal(for: s.endDate),
                day: dayString(s.endDate), timestamp: s.endDate, nutrients: n,
                source: "Apple Health · \(s.sourceName)", externalId: s.externalId)
        }
    }

    /// One weight entry per body-mass sample, enriched with the nearest
    /// body-fat / lean-mass / BMI sample within 10 minutes (scale
    /// readings like HealthU+'s arrive as a same-moment cluster).
    public static func weightEntries(bodyMass: [HealthSample],
                                     bodyFat: [HealthSample] = [],
                                     leanMass: [HealthSample] = [],
                                     bmi: [HealthSample] = []) -> [WeightEntry] {
        bodyMass.map { m in
            func nearest(_ list: [HealthSample]) -> Double? {
                list.min(by: {
                    abs($0.endDate.timeIntervalSince(m.endDate))
                        < abs($1.endDate.timeIntervalSince(m.endDate))
                }).flatMap {
                    abs($0.endDate.timeIntervalSince(m.endDate)) <= 600 ? $0.value : nil
                }
            }
            return WeightEntry(
                date: m.endDate, kg: m.value,
                source: "Apple Health · \(m.sourceName)", externalId: m.externalId,
                bodyFatPercent: nearest(bodyFat),
                leanMassKg: nearest(leanMass), bmi: nearest(bmi))
        }
    }

    public static func workoutSessions(from workouts: [HealthWorkout]) -> [WorkoutSession] {
        workouts.map { w in
            WorkoutSession(
                routineName: w.activityName, startedAt: w.startDate,
                endedAt: w.endDate, notes: "Imported from Apple Health (\(w.sourceName))",
                source: "Apple Health · \(w.sourceName)", externalId: w.externalId,
                activeEnergyKcal: w.totalEnergyKcal, hkActivityName: w.activityName)
        }
    }

    // MARK: - Lossless merge (dedupe by HealthKit UUID, update in place)

    public struct MergeReport: Hashable {
        public var added: Int
        public var updated: Int
        public var skipped: Int
        public init(added: Int = 0, updated: Int = 0, skipped: Int = 0) {
            self.added = added
            self.updated = updated
            self.skipped = skipped
        }
    }

    public static func mergeWeights(current: [WeightEntry],
                                    incoming: [WeightEntry]) -> ([WeightEntry], MergeReport) {
        var out = current
        var report = MergeReport()
        for w in incoming {
            if let id = w.externalId,
               let i = out.firstIndex(where: { $0.externalId == id }) {
                if out[i] == w { report.skipped += 1 } else { out[i] = w; report.updated += 1 }
            } else {
                out.append(w); report.added += 1
            }
        }
        return (out, report)
    }

    public static func mergeDiary(current: [DiaryEntry],
                                  incoming: [DiaryEntry]) -> ([DiaryEntry], MergeReport) {
        var out = current
        var report = MergeReport()
        for e in incoming {
            if let id = e.externalId,
               let i = out.firstIndex(where: { $0.externalId == id }) {
                if out[i] == e { report.skipped += 1 } else { out[i] = e; report.updated += 1 }
            } else {
                out.append(e); report.added += 1
            }
        }
        return (out, report)
    }

    public static func mergeSessions(current: [WorkoutSession],
                                     incoming: [WorkoutSession]) -> ([WorkoutSession], MergeReport) {
        var out = current
        var report = MergeReport()
        for s in incoming {
            if let id = s.externalId,
               let i = out.firstIndex(where: { $0.externalId == id }) {
                if out[i] == s { report.skipped += 1 } else { out[i] = s; report.updated += 1 }
            } else {
                out.append(s); report.added += 1
            }
        }
        return (out, report)
    }

    /// Water is stored per day, so samples are tracked by UUID per day and
    /// only new millilitres are added — re-imports never double-count.
    public static func mergeWater(current: [WaterIntake],
                                  samples: [HealthSample]) -> ([WaterIntake], MergeReport) {
        var out = current
        var report = MergeReport()
        let byDay = Dictionary(grouping: samples, by: { dayString($0.endDate) })
        for (day, list) in byDay {
            let ids = Set(list.map(\.externalId))
            if let i = out.firstIndex(where: { $0.day == day }) {
                let known = Set(out[i].externalIds ?? [])
                let fresh = ids.subtracting(known)
                if fresh.isEmpty { report.skipped += 1; continue }
                let freshMl = list.filter { fresh.contains($0.externalId) }
                    .reduce(0) { $0 + $1.value }
                out[i].ml += freshMl
                out[i].externalIds = Array(known.union(fresh))
                out[i].source = "Apple Health"
                report.updated += 1
            } else {
                let ml = list.reduce(0) { $0 + $1.value }
                out.append(WaterIntake(day: day, ml: ml, source: "Apple Health",
                                       externalIds: Array(ids)))
                report.added += 1
            }
        }
        return (out, report)
    }

    /// Honor deletions reported by HealthKit — but only for entries this
    /// import created. Manual entries are never touched.
    public static func applyDeletions(weights: [WeightEntry], diary: [DiaryEntry],
                                      sessions: [WorkoutSession],
                                      hkUUIDs: Set<String>) -> ([WeightEntry], [DiaryEntry], [WorkoutSession], Int) {
        let ids = Set(hkUUIDs.map { "hk:\($0)" })
        let w = weights.filter { !($0.externalId.map(ids.contains) ?? false) }
        let d = diary.filter { !($0.externalId.map(ids.contains) ?? false) }
        let s = sessions.filter { !($0.externalId.map(ids.contains) ?? false) }
        let removed = (weights.count - w.count) + (diary.count - d.count) + (sessions.count - s.count)
        return (w, d, s, removed)
    }
}
