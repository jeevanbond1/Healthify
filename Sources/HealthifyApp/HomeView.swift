import SwiftUI
import HealthifyCore

// MARK: - Home: today's target vs actual vs burn, bold and clean.

struct HomeView: View {
    @EnvironmentObject var store: UserStore

    private var today: String { dayString() }
    private var eaten: Double { store.totals(on: today).kcal }
    private var target: Double { store.goal.targetKcal }
    private var remaining: Double { target - eaten }
    private var burn: EnergyBurn.DayBurn {
        let kinds = Dictionary(uniqueKeysWithValues:
            libraryExercises(custom: store.customExercises).map { ($0.id, $0.kind) })
        return EnergyBurn.todayBurn(sessions: store.sessions, day: today,
                                    weightKg: store.goal.weightKg, kinds: kinds)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Today target")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text("\(fmt(target)) kcal")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            HStack(spacing: 16) {
                                stat("Actual", "\(fmt(eaten)) kcal", bold: true)
                                stat("Remaining", "\(fmt(remaining)) kcal", bold: true)
                            }
                            Text("Target + burn − eaten = \(fmt(target + burn.total - eaten)) kcal"
                                + (burn.hasEstimate ? " (burn estimated)" : ""))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Burned today").font(.headline)
                            HStack(spacing: 16) {
                                stat("Workout", "\(fmt(burn.workoutKcal)) kcal", bold: true)
                                stat("Cardio", "\(fmt(burn.cardioKcal)) kcal", bold: true)
                            }
                            if burn.hasEstimate {
                                Text("Estimated from workout duration and your weight. "
                                    + "Apple Health workouts use their recorded energy.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    NavigationLink {
                        ProgressView()
                    } label: {
                        GlassCard {
                            HStack {
                                Text("Progress: weight, records, 7 days")
                                    .font(.subheadline.bold())
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .navigationTitle(greeting)
        }
    }

    private var greeting: String {
        if let n = store.goal.displayName, !n.isEmpty { return "Hi, \(n)" }
        return "Today"
    }

    private func stat(_ label: String, _ value: String, bold: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(bold ? .title3.bold() : .title3).monospacedDigit()
        }
    }
}
