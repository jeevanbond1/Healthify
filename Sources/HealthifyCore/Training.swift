import Foundation

// MARK: - Goals

public enum Sex: String, Codable, CaseIterable {
    case female, male
}

public enum ActivityLevel: String, Codable, CaseIterable {
    case sedentary, light, moderate, active, veryActive

    public var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }

    public var label: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Lightly active"
        case .moderate: return "Moderately active"
        case .active: return "Active"
        case .veryActive: return "Very active"
        }
    }
}

public enum GoalDirection: String, Codable, CaseIterable {
    case lose, maintain, gain
}

public struct GoalProfile: Codable, Hashable {
    /// Greeting name from first setup. Nil in old backups.
    public var displayName: String?
    public var sex: Sex
    public var age: Int
    public var heightCm: Double
    public var weightKg: Double
    /// Target body weight from first setup / Settings. Nil in old backups.
    public var targetWeightKg: Double?
    public var activity: ActivityLevel
    public var goal: GoalDirection
    /// Desired change per week in kg, 0.25...1.0. Ignored on maintain.
    public var weeklyKg: Double
    public var proteinPct: Double
    public var carbsPct: Double
    public var fatPct: Double
    // Cached targets, recomputed by GoalEngine.
    public var targetKcal: Double
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double

    public init(displayName: String? = nil, sex: Sex = .female, age: Int = 30,
                heightCm: Double = 165,
                weightKg: Double = 65, targetWeightKg: Double? = nil,
                activity: ActivityLevel = .moderate,
                goal: GoalDirection = .maintain, weeklyKg: Double = 0.5,
                proteinPct: Double = 25, carbsPct: Double = 45,
                fatPct: Double = 30, targetKcal: Double = 2000,
                proteinG: Double = 125, carbsG: Double = 225, fatG: Double = 67) {
        self.displayName = displayName
        self.sex = sex
        self.age = age
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.targetWeightKg = targetWeightKg
        self.activity = activity
        self.goal = goal
        self.weeklyKg = weeklyKg
        self.proteinPct = proteinPct
        self.carbsPct = carbsPct
        self.fatPct = fatPct
        self.targetKcal = targetKcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
    }
}

public enum Units: String, Codable, CaseIterable {
    case metric, imperial
}

public struct AppSettings: Codable, Hashable {
    public var units: Units
    public var backupReminderEnabled: Bool
    public init(units: Units = .metric, backupReminderEnabled: Bool = true) {
        self.units = units
        self.backupReminderEnabled = backupReminderEnabled
    }
}

// MARK: - Training

public enum ExerciseKind: String, Codable, CaseIterable {
    case weighted, bodyweight, timed, cardio
}

public struct Exercise: Codable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var muscleGroup: String
    public var equipment: String
    public var kind: ExerciseKind

    public init(id: UUID = UUID(), name: String, muscleGroup: String,
                equipment: String, kind: ExerciseKind) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = equipment
        self.kind = kind
    }
}

public struct RoutineItem: Codable, Hashable {
    public var exerciseId: UUID
    public var targetSets: Int
    public var note: String?
    /// Planned reps / weight per set. Nil in old backups.
    public var targetReps: Double?
    public var targetWeightKg: Double?

    public init(exerciseId: UUID, targetSets: Int, note: String? = nil,
                targetReps: Double? = nil, targetWeightKg: Double? = nil) {
        self.exerciseId = exerciseId
        self.targetSets = targetSets
        self.note = note
        self.targetReps = targetReps
        self.targetWeightKg = targetWeightKg
    }
}

/// One weekday in the weekly training calendar. Weekday: Mon=1 ... Sun=7.
public struct WeekPlanDay: Codable, Hashable, Identifiable {
    public var weekday: Int
    public var routineId: UUID?
    public var muscleLabel: String?
    public var id: Int { weekday }

    public init(weekday: Int, routineId: UUID? = nil, muscleLabel: String? = nil) {
        self.weekday = weekday
        self.routineId = routineId
        self.muscleLabel = muscleLabel
    }

    public static let names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    public var shortName: String {
        (1...7).contains(weekday) ? Self.names[weekday - 1] : "?"
    }
}

public struct Routine: Codable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var items: [RoutineItem]

    public init(id: UUID = UUID(), name: String, items: [RoutineItem]) {
        self.id = id
        self.name = name
        self.items = items
    }
}

public struct WorkoutSet: Codable, Hashable, Identifiable {
    public var id: UUID
    public var reps: Double?
    public var weightKg: Double?
    public var seconds: Double?
    public var distanceM: Double?

    public init(id: UUID = UUID(), reps: Double? = nil, weightKg: Double? = nil,
                seconds: Double? = nil, distanceM: Double? = nil) {
        self.id = id
        self.reps = reps
        self.weightKg = weightKg
        self.seconds = seconds
        self.distanceM = distanceM
    }

    /// Set volume in kg-reps; 0 for timed/cardio sets.
    public var volume: Double {
        (reps ?? 0) * (weightKg ?? 0)
    }
}

public struct SessionEntry: Codable, Hashable, Identifiable {
    public var id: UUID
    public var exerciseId: UUID
    public var sets: [WorkoutSet]
    public init(id: UUID = UUID(), exerciseId: UUID, sets: [WorkoutSet] = []) {
        self.id = id
        self.exerciseId = exerciseId
        self.sets = sets
    }
}

public struct WorkoutSession: Codable, Hashable, Identifiable {
    public var id: UUID
    public var routineId: UUID?
    public var routineName: String?
    public var startedAt: Date
    public var endedAt: Date?
    public var entries: [SessionEntry]
    public var notes: String?
    public var source: String?
    public var externalId: String?
    public var activeEnergyKcal: Double?
    public var hkActivityName: String?

    public init(id: UUID = UUID(), routineId: UUID? = nil,
                routineName: String? = nil, startedAt: Date = Date(),
                endedAt: Date? = nil, entries: [SessionEntry] = [],
                notes: String? = nil, source: String? = nil,
                externalId: String? = nil, activeEnergyKcal: Double? = nil,
                hkActivityName: String? = nil) {
        self.id = id
        self.routineId = routineId
        self.routineName = routineName
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.entries = entries
        self.notes = notes
        self.source = source
        self.externalId = externalId
        self.activeEnergyKcal = activeEnergyKcal
        self.hkActivityName = hkActivityName
    }

    public var volume: Double {
        entries.flatMap(\.sets).reduce(0) { $0 + $1.volume }
    }

    public var day: String { dayString(startedAt) }
}
