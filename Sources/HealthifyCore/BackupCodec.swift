import Foundation

// MARK: - Backup file format (v1)

/// Everything the user owns. Bundled seed data is never exported.
public struct BackupBody: Codable {
    public var customFoods: [FoodItem] = []
    public var recipes: [Recipe] = []
    public var diary: [DiaryEntry] = []
    public var water: [WaterIntake] = []
    public var weight: [WeightEntry] = []
    public var routines: [Routine] = []
    public var weekPlan: [WeekPlanDay] = []
    public var sessions: [WorkoutSession] = []
    public var customExercises: [Exercise] = []
    public var goal: GoalProfile?
    public var settings: AppSettings = AppSettings()
    public init() {}
}

public struct BackupFile: Codable {
    public var schemaVersion: Int
    public var exportedAt: Date
    public var counts: [String: Int]
    public var checksum: String
    public var body: BackupBody
}

public enum BackupMode {
    case replace, merge
}

public enum BackupError: Error, LocalizedError {
    case unsupportedVersion(Int)
    case checksumMismatch
    case decodingFailed
    case emptyFile

    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let v):
            return "Backup version \(v) is not supported by this app."
        case .checksumMismatch:
            return "Backup file is damaged (checksum mismatch). Nothing was changed."
        case .decodingFailed:
            return "Could not read backup file. Nothing was changed."
        case .emptyFile:
            return "Backup file is empty."
        }
    }
}

public enum BackupCodec {
    public static let schemaVersion = 1

    /// FNV-1a 64-bit: tiny, dependency-free, good enough for damage checks.
    public static func fnv1a(_ data: Data) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in data {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }

    private static func bodyData(_ body: BackupBody) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(body)
    }

    public static func encode(_ body: BackupBody) throws -> Data {
        let raw = try bodyData(body)
        let mirror = Mirror(reflecting: body)
        var counts: [String: Int] = [:]
        for child in mirror.children {
            guard let label = child.label else { continue }
            counts[label] = (child.value as? [Any])?.count ?? 1
        }
        let file = BackupFile(schemaVersion: schemaVersion, exportedAt: Date(),
                              counts: counts, checksum: fnv1a(raw), body: body)
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .prettyPrinted]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(file)
    }

    /// Validates version + checksum. Never mutates anything.
    public static func validate(_ data: Data) throws -> BackupFile {
        guard !data.isEmpty else { throw BackupError.emptyFile }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let file = try? dec.decode(BackupFile.self, from: data) else {
            throw BackupError.decodingFailed
        }
        guard file.schemaVersion == schemaVersion else {
            throw BackupError.unsupportedVersion(file.schemaVersion)
        }
        let raw = try bodyData(file.body)
        guard fnv1a(raw) == file.checksum else { throw BackupError.checksumMismatch }
        return file
    }

    /// Merge incoming data into current, skipping duplicates. Returns report lines.
    public static func merge(current: BackupBody,
                             incoming: BackupBody) -> (BackupBody, [String]) {
        var out = current
        var report: [String] = []
        func add<T: Identifiable>(items: [T], to list: inout [T],
                                  label: String) where T.ID == UUID {
            let known = Set(list.map(\.id))
            let fresh = items.filter { !known.contains($0.id) }
            list.append(contentsOf: fresh)
            report.append("\(label): \(fresh.count) added, "
                + "\(items.count - fresh.count) already present")
        }
        add(items: incoming.customFoods, to: &out.customFoods, label: "Foods")
        add(items: incoming.recipes, to: &out.recipes, label: "Recipes")
        add(items: incoming.diary, to: &out.diary, label: "Diary entries")
        add(items: incoming.sessions, to: &out.sessions, label: "Workouts")
        add(items: incoming.routines, to: &out.routines, label: "Routines")
        if !incoming.weekPlan.isEmpty { out.weekPlan = incoming.weekPlan }
        add(items: incoming.customExercises, to: &out.customExercises,
            label: "Exercises")
        add(items: incoming.weight, to: &out.weight, label: "Weigh-ins")
        let knownDays = Set(out.water.map(\.day))
        let freshWater = incoming.water.filter { !knownDays.contains($0.day) }
        out.water.append(contentsOf: freshWater)
        report.append("Water days: \(freshWater.count) added")
        return (out, report)
    }
}
