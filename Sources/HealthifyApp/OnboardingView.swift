import SwiftUI
import HealthifyCore

/// First-run setup only (or after Delete-all reset). No login, no network;
/// everything stays on device. Steps: name -> body data -> target -> review.
struct OnboardingView: View {
    @EnvironmentObject var store: UserStore
    @EnvironmentObject var health: HealthKitSyncService
    @State private var step = 0
    @State private var name = ""
    @State private var sex: Sex = .female
    @State private var age = 30
    @State private var heightCm = 165.0
    @State private var weightKg = 65.0
    @State private var activity: ActivityLevel = .moderate
    @State private var targetWeightKg = 60.0
    @State private var weeklyKg = 0.5
    @State private var synced = false
    @State private var syncNote: String?

    private var draft: GoalProfile {
        GoalProfile(displayName: name.trimmingCharacters(in: .whitespaces),
                    sex: sex, age: age, heightCm: heightCm,
                    weightKg: weightKg, targetWeightKg: targetWeightKg,
                    activity: activity,
                    goal: GoalEngine.direction(currentKg: weightKg,
                                               targetKg: targetWeightKg),
                    weeklyKg: weeklyKg,
                    proteinPct: 25, carbsPct: 45, fatPct: 30)
    }

    private var preview: GoalProfile { GoalEngine.retarget(draft) }

    private var canContinue: Bool {
        switch step {
        case 0: return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return heightCm > 0 && weightKg > 0 && (13...100).contains(age)
        case 2: return targetWeightKg > 0
        default: return true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ProgressView(value: Double(step + 1) / 4)
                    .padding(.horizontal)
                Group {
                    switch step {
                    case 0: nameStep
                    case 1: bodyStep
                    case 2: targetStep
                    default: reviewStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                HStack(spacing: 12) {
                    if step > 0 {
                        Button("Back") { withAnimation(.uiSpring) { step -= 1 } }
                            .buttonStyle(.bordered)
                    }
                    Spacer()
                    if step < 3 {
                        Button("Continue") {
                            Haptics.tap()
                            withAnimation(.uiSpring) { step += 1 }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canContinue)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: Step 1 - name

    private var nameStep: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to Healthify").font(.title2.bold())
                    Text("Local-only diet + gym tracker. No login, "
                        + "everything stays on this phone.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            Section("Your name") {
                TextField("Name (required)", text: $name)
                    .textContentType(.name)
            }
        }
    }

    // MARK: Step 2 - body data: sync or manual

    private var bodyStep: some View {
        Form {
            Section("Weight & height") {
                Button {
                    Task { await syncFromHealth() }
                } label: {
                    Label(synced ? "Synced from Apple Health"
                                 : "Sync from Apple Health / HealthU+",
                          systemImage: synced ? "checkmark.circle.fill" : "heart.text.square")
                }
                .disabled(health.status == .syncing)
                if let syncNote {
                    Text(syncNote).font(.caption).foregroundStyle(.secondary)
                }
                Text("HealthU+ scale? Enable its Apple Health sync first, "
                    + "step on the scale, then tap Sync above. "
                    + "Or just type your numbers below.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("About you") {
                Picker("Sex", selection: $sex) {
                    Text("Female").tag(Sex.female)
                    Text("Male").tag(Sex.male)
                }
                Stepper("Age: \(age)", value: $age, in: 13...100)
                HStack {
                    Text("Height (cm)"); Spacer()
                    TextField("cm", value: $heightCm, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing).frame(width: 80)
                }
                HStack {
                    Text("Weight (kg)"); Spacer()
                    TextField("kg", value: $weightKg, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing).frame(width: 80)
                }
                Picker("Activity", selection: $activity) {
                    ForEach(ActivityLevel.allCases, id: \.self) { a in
                        Text(a.label).tag(a)
                    }
                }
            }
        }
    }

    private func syncFromHealth() async {
        await health.requestAccess()
        guard health.status == .connected else {
            syncNote = health.lastError ?? "Permission needed to read Apple Health."
            return
        }
        await health.sync(into: store)
        if let last = store.weight.sorted(by: { $0.date < $1.date }).last {
            weightKg = last.kg
        }
        heightCm = store.goal.heightCm
        synced = true
        syncNote = health.lastReport ?? "Synced."
        Haptics.success()
    }

    // MARK: Step 3 - target weight + pace

    private var targetStep: some View {
        Form {
            Section("Target weight") {
                HStack {
                    Text("Goal (kg)"); Spacer()
                    TextField("kg", value: $targetWeightKg, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing).frame(width: 80)
                }
                Text(directionText).font(.caption).foregroundStyle(.secondary)
            }
            Section("How fast?") {
                Picker("Pace", selection: $weeklyKg) {
                    Text("Gentle").tag(0.25)
                    Text("Steady").tag(0.5)
                    Text("Faster").tag(0.75)
                    Text("Aggressive").tag(1.0)
                }
                .pickerStyle(.segmented)
                Text("\(fmt(weeklyKg, 2)) kg / week")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Your daily target") {
                LabeledContent("Calories", value: "\(fmt(preview.targetKcal)) kcal")
                LabeledContent("Protein", value: "\(fmt(preview.proteinG)) g")
                LabeledContent("Carbs", value: "\(fmt(preview.carbsG)) g")
                LabeledContent("Fat", value: "\(fmt(preview.fatG)) g")
                let days = GoalEngine.estimatedDays(currentKg: weightKg,
                                                    targetKg: targetWeightKg,
                                                    weeklyKg: weeklyKg)
                LabeledContent("Estimated time",
                               value: days == 0 ? "Already there"
                                   : "\(days) days (~\(fmt(Double(days) / 7, 1)) weeks)")
            }
        }
    }

    private var directionText: String {
        switch draft.goal {
        case .lose: return "Lose \(fmt(weightKg - targetWeightKg, 1)) kg"
        case .gain: return "Gain \(fmt(targetWeightKg - weightKg, 1)) kg"
        case .maintain: return "Maintain around \(fmt(weightKg, 1)) kg"
        }
    }

    // MARK: Step 4 - review

    private var reviewStep: some View {
        Form {
            Section("Ready, \(draft.displayName ?? "there")?") {
                LabeledContent("Now", value: "\(fmt(weightKg, 1)) kg")
                LabeledContent("Target", value: "\(fmt(targetWeightKg, 1)) kg")
                LabeledContent("Pace", value: "\(fmt(weeklyKg, 2)) kg / week")
                LabeledContent("Daily calories", value: "\(fmt(preview.targetKcal)) kcal")
                LabeledContent("Estimated time",
                               value: "\(GoalEngine.estimatedDays(currentKg: weightKg, targetKg: targetWeightKg, weeklyKg: weeklyKg)) days")
            }
            Section {
                Button("Start tracking") {
                    Haptics.commit()
                    if store.routines.isEmpty {
                        for r in seedRoutines(exercises: seedExercises) {
                            store.addRoutine(r)
                        }
                    }
                    if store.weekPlan.isEmpty, store.routines.count >= 6 {
                        // Push / Pull / Legs seeded; every day editable in Weekly plan.
                        store.setPlan(weekday: 1, routineId: store.routines[2].id,
                                      muscleLabel: "Chest + Shoulders + Arms")
                        store.setPlan(weekday: 2, routineId: store.routines[3].id,
                                      muscleLabel: "Back + Arms")
                        store.setPlan(weekday: 3, routineId: store.routines[4].id,
                                      muscleLabel: "Legs")
                        store.setPlan(weekday: 5, routineId: store.routines[2].id,
                                      muscleLabel: "Chest + Shoulders + Arms")
                        store.setPlan(weekday: 6, routineId: store.routines[5].id,
                                      muscleLabel: "Cardio + Core")
                    }
                    if targetWeightKg == 0 { targetWeightKg = weightKg }
                    store.completeOnboarding(with: draft)
                }
                .frame(maxWidth: .infinity)
            } footer: {
                Text("General wellness guidance only. "
                    + "You can change the target anytime in Settings.")
            }
        }
    }
}
