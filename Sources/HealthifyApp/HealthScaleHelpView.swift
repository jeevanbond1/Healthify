import SwiftUI

// MARK: - Scale setup: HealthU+ (Lefu) writes to Apple Health; we read it.

struct HealthScaleHelpView: View {
    var body: some View {
        List {
            Section {
                Text("Healthify reads scale data out of Apple Health — "
                    + "your scale app writes it there first. Set this up once:")
                    .font(.subheadline)
            }
            Section("HealthU+ scale app") {
                labeledStep(1, "Open the HealthU+ app on your iPhone.")
                labeledStep(2, "Open your profile or Me, then Apple Health (or HealthKit).")
                labeledStep(3, "Turn on Weight, Body Fat %, Lean Body Mass and BMI.")
                labeledStep(4, "Step on the scale and finish a measurement.")
                labeledStep(5, "Return here and tap Sync now. Your weigh-in appears "
                    + "with its body-fat and lean-mass readings attached.")
            }
            Section("Permissions") {
                labeledStep(1, "When Healthify asks, allow the Weight, Body Fat, "
                    + "Nutrition and Workout categories it requests.")
                labeledStep(2, "To change your mind later: iPhone Settings → "
                    + "Privacy & Security → Health → Healthify.")
                Text("Healthify only reads. It never writes to Apple Health "
                    + "and never uploads anything anywhere.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Other scales") {
                Text("Any scale app that offers an Apple Health / HealthKit "
                    + "sync — Renpho, Withings, Eufy, Wyze and others — works "
                    + "the same way: enable its Health sync, weigh yourself, "
                    + "then Sync now here.")
                    .font(.subheadline)
            }
        }
        .navigationTitle("Scale setup")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func labeledStep(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)").font(.headline).foregroundStyle(.accent)
                .frame(width: 20)
            Text(text).font(.subheadline)
        }
        .padding(.vertical, 2)
    }
}
