import SwiftUI
import HealthifyCore

// MARK: - Progress: calories vs target, weight trend, gym volume, PRs.

struct ProgressView: View {
    @EnvironmentObject var store: UserStore
    @State private var weightDraft = 65.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var last7: [(day: String, volume: Double)] {
        WorkoutStats.volumeByDay(sessions: store.sessions, lastDays: 7)
    }

    private var sortedWeights: [WeightEntry] {
        store.weight.sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Calories vs target · last 7 days")
                                .font(.headline)
                            DayBars(values: last7Days.map { $0.eaten },
                                    targets: last7Days.map { $0.target })
                        }
                    }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Weight").font(.headline)
                                Spacer()
                                if let last = sortedWeights.last {
                                    Text("\(fmt(last.kg, 1)) kg")
                                        .font(.headline).monospacedDigit()
                                }
                            }
                            if let last = sortedWeights.last,
                               last.bodyFatPercent != nil || last.leanMassKg != nil {
                                HStack(spacing: 12) {
                                    if let bf = last.bodyFatPercent {
                                        Text("Fat \(fmt(bf, 1))%")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    if let lean = last.leanMassKg {
                                        Text("Lean \(fmt(lean, 1)) kg")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    if let src = last.source {
                                        Text(src).font(.caption2).foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            if sortedWeights.count >= 2,
                               let first = sortedWeights.first,
                               let last = sortedWeights.last {
                                let delta = last.kg - first.kg
                                Text("\(delta >= 0 ? "+" : "")\(fmt(delta, 1)) kg "
                                    + "since \(dayString(first.date))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            HStack {
                                TextField("kg", value: $weightDraft, format: .number)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 90)
                                Button("Log weigh-in") {
                                    Haptics.commit()
                                    store.addWeight(kg: weightDraft)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Gym volume · last 7 days").font(.headline)
                            DayBars(values: last7.map { $0.volume },
                                    targets: nil,
                                    suffix: "kg")
                        }
                    }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Personal records").font(.headline)
                            let records = recordsList
                            if records.isEmpty {
                                Text("Log a weighted set to set your first record.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            ForEach(records) { r in
                                HStack {
                                    Label(r.name, systemImage: "trophy")
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(fmt(r.best, 0)) kg")
                                        .font(.subheadline).monospacedDigit()
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .keyboardDoneToolbar()
            .navigationTitle("Progress")
        }
    }

    private var last7Days: [(day: String, eaten: Double, target: Double)] {
        let cal = Calendar.current
        let now = Date()
        return (0..<7).map { back in
            let d = cal.date(byAdding: .day, value: -back, to: now) ?? now
            let key = dayString(d)
            return (key, store.totals(on: key).kcal, store.goal.targetKcal)
        }.reversed()
    }

    private struct PRRecord: Identifiable {
        var id: String { name }
        var name: String
        var best: Double
    }

    private var recordsList: [PRRecord] {
        libraryExercises(custom: store.customExercises).compactMap { ex in
            guard ex.kind == .weighted,
                  let best = WorkoutStats.bestWeightKg(exerciseId: ex.id,
                                                       in: store.sessions) else {
                return nil
            }
            return PRRecord(name: ex.name, best: best)
        }
        .sorted { $0.name < $1.name }
    }
}

/// Seven bars, animated from current values; targets drawn as caps.
struct DayBars: View {
    var values: [Double]
    var targets: [Double]?
    var suffix = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(values.indices, id: \.self) { i in
                let maxV = max(values.max() ?? 1,
                               targets?[i] ?? 0, 1)
                VStack(spacing: 4) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.quaternary)
                            .frame(height: 90)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor)
                            .frame(height: max(4, 90 * values[i] / maxV))
                    }
                    .overlay(alignment: .top) {
                        if let t = targets, i < t.count {
                            Rectangle()
                                .fill(.primary)
                                .frame(height: 2)
                                .offset(y: 90 * (1 - min(t[i] / maxV, 1)))
                        }
                    }
                    Text(dayLabel(i))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .animation(Motion.adaptive(reduce: reduceMotion),
                           value: values[i])
            }
        }
    }

    private func dayLabel(_ i: Int) -> String {
        let cal = Calendar.current
        let d = cal.date(byAdding: .day,
                         value: i - (values.count - 1), to: Date()) ?? Date()
        let f = DateFormatter()
        f.dateFormat = "E"
        return f.string(from: d)
    }
}
