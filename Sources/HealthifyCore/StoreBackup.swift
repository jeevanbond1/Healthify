#if canImport(Combine)
import Foundation

// MARK: - Export / import, executed by the store

extension UserStore {
    private func body() -> BackupBody {
        var b = BackupBody()
        b.customFoods = customFoods
        b.recipes = recipes
        b.diary = diary
        b.water = water
        b.weight = weight
        b.routines = routines
        b.weekPlan = weekPlan
        b.sessions = sessions
        b.customExercises = customExercises
        b.goal = goal
        b.settings = settings
        return b
    }

    private func apply(_ b: BackupBody, onboarded: Bool = true) {
        customFoods = b.customFoods
        recipes = b.recipes
        diary = b.diary
        water = b.water
        weight = b.weight
        routines = b.routines
        weekPlan = b.weekPlan
        sessions = b.sessions
        customExercises = b.customExercises
        if let g = b.goal { goal = g }
        settings = b.settings
        self.onboarded = onboarded
    }

    /// Encode the full backup file. Pure until the write the caller does.
    public func exportBackup() throws -> Data {
        try BackupCodec.encode(body())
    }

    /// Validate → preview is the caller's job → apply. Snapshot first.
    /// - Returns: human-readable report lines for the confirm screen.
    @discardableResult
    public func importBackup(_ data: Data, mode: BackupMode) throws -> [String] {
        let file = try BackupCodec.validate(data)
        // Pre-import snapshot: a bad import choice stays undoable.
        let snap = try BackupCodec.encode(body())
        UserDefaults.standard.set(snap, forKey: "Healthify.lastSnapshot")
        switch mode {
        case .replace:
            apply(file.body)
            save()
            return ["Replaced all data with backup from "
                + file.exportedAt.formatted(date: .abbreviated, time: .short) + "."]
        case .merge:
            let (merged, report) = BackupCodec.merge(current: body(),
                                                     incoming: file.body)
            apply(merged)
            save()
            return report
        }
    }

    /// Restore the snapshot taken before the last import.
    public func undoLastImport() throws {
        guard let snap = UserDefaults.standard.data(forKey: "Healthify.lastSnapshot") else {
            return
        }
        let file = try BackupCodec.validate(snap)
        apply(file.body)
        save()
    }

    // MARK: - CSV (spreadsheets, not restore)

    public func diaryCSV(days: Int = 30, now: Date = Date()) -> String {
        var rows = ["day,meal,food,grams,kcal,protein_g,carbs_g,fat_g"]
        let cal = Calendar.current
        for back in 0..<days {
            guard let d = cal.date(byAdding: .day, value: -back, to: now) else { continue }
            let key = dayString(d)
            for e in entries(on: key) {
                let n = e.nutrients
                rows.append([key, e.meal.rawValue, "\"\(e.name)\"",
                             String(format: "%.0f", e.grams),
                             String(format: "%.0f", n.kcal),
                             String(format: "%.1f", n.proteinG),
                             String(format: "%.1f", n.carbsG),
                             String(format: "%.1f", n.fatG)].joined(separator: ","))
            }
        }
        return rows.joined(separator: "\n")
    }
}
#endif
