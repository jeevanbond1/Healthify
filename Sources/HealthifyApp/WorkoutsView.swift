import SwiftUI
import HealthifyCore

// MARK: - Workouts: routines in, live session, history out.

struct WorkoutsView: View {
    @EnvironmentObject var store: UserStore
    @State private var liveRoutine: Routine?
    @State private var liveActive = false

    private var todayWeekday: Int {
        // Calendar: Sun=1...Sat=7 -> Mon=1...Sun=7
        (Calendar.current.component(.weekday, from: Date()) + 5) % 7 + 1
    }
    private var exerciseMap: [UUID: Exercise] {
        Dictionary(uniqueKeysWithValues:
            libraryExercises(custom: store.customExercises).map { ($0.id, $0) })
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    weekStrip
                } header: { Text("This week") }
                Section("Today") {
                    if let plan = store.plan(forWeekday: todayWeekday),
                       let rid = plan.routineId,
                       let routine = store.routines.first(where: { $0.id == rid }) {
                        Text(plan.muscleLabel ?? routine.name)
                            .font(.headline)
                        ForEach(routine.items, id: \.exerciseId) { item in
                            HStack {
                                Text(exerciseMap[item.exerciseId]?.name ?? "Exercise")
                                    .font(.subheadline)
                                Spacer()
                                Text(todayTargetText(item))
                                    .font(.caption).foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        if let prev = WorkoutStats.previousSession(
                            routineId: routine.id, before: Date(), in: store.sessions) {
                            Text("Last time \(prev.day): " + routine.items.compactMap { item in
                                guard let p = WorkoutStats.lastPerformance(
                                    exerciseId: item.exerciseId, before: Date(),
                                    in: store.sessions) else { return nil }
                                return "\(exerciseMap[item.exerciseId]?.name ?? "") \(fmt(p.weightKg, 0)) kg × \(fmt(p.reps, 0))"
                            }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Button("Start today's workout") {
                            Haptics.tap(); liveRoutine = routine; liveActive = true
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Text("Rest day — no workout planned for today.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    NavigationLink("Weekly plan") { WeekPlanView() }
                }
                Section {
                    Button {
                        Haptics.tap()
                        liveRoutine = nil
                        liveActive = true
                    } label: {
                        Label("Start empty workout (add any exercise)", systemImage: "plus.circle.fill")
                    }
                }
                Section("Routines") {
                    ForEach(store.routines) { routine in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(routine.name)
                                Text("\(routine.items.count) exercises")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Start") {
                                Haptics.tap()
                                liveRoutine = routine
                                liveActive = true
                            }
                            .buttonStyle(.bordered)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.deleteRoutine(routine)
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
                Section("History") {
                    ForEach(store.sessions.sorted { $0.startedAt > $1.startedAt }) { s in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.routineName ?? "Workout")
                            Text("\(dayString(s.startedAt)) · "
                                + "\(fmt(s.volume, 0)) kg volume · "
                                + "\(s.entries.reduce(0) { $0 + $1.sets.count }) sets"
                                + (s.activeEnergyKcal.map { " · \(fmt($0, 0)) kcal" } ?? "")
                                + (s.source.map { " · \($0)" } ?? ""))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.deleteSession(s)
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
            }
            .navigationTitle("Workouts")
                // Completion feedback lives in the session's own summary
                // sheet (presented before dismissal), never stacked on
                // top of the full-screen cover.
                .fullScreenCover(isPresented: $liveActive) {
                    LiveSessionView(
                        routine: liveRoutine,
                        exerciseMap: Dictionary(
                            uniqueKeysWithValues:
                                libraryExercises(custom: store.customExercises)
                                .map { ($0.id, $0) }),
                        priorSessions: store.sessions
                    ) { finished, _ in
                        store.finishSession(finished)
                        Haptics.success()
                    }
                }
        }
    }

    private func todayTargetText(_ item: RoutineItem) -> String {
        var parts = ["\(item.targetSets) sets"]
        if let r = item.targetReps { parts.append("\(fmt(r, 0)) reps") }
        if let w = item.targetWeightKg { parts.append("\(fmt(w, 0)) kg") }
        if item.targetReps == nil, let p = WorkoutStats.lastPerformance(
            exerciseId: item.exerciseId, before: Date(), in: store.sessions) {
            let next = WorkoutStats.suggestedWeight(lastWeightKg: p.weightKg,
                                                    lastReps: p.reps)
            parts.append("last: \(fmt(p.weightKg, 0)) kg × \(fmt(p.reps, 0)) → try \(fmt(next, 1)) kg")
        }
        return parts.joined(separator: " · ")
    }

    private var weekStrip: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { weekday in
                let plan = store.plan(forWeekday: weekday)
                let isToday = weekday == todayWeekday
                VStack(spacing: 4) {
                    Text(WeekPlanDay.names[weekday - 1])
                        .font(.caption2.bold())
                        .foregroundStyle(isToday ? .white : .secondary)
                    Circle()
                        .fill(plan?.routineId == nil ? Color.gray.opacity(0.25) : Color.accentColor)
                        .frame(width: 10, height: 10)
                    Text(plan?.routineId == nil ? "Rest" : "Train")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isToday ? Color.accentColor.opacity(0.85) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(isToday ? .white : .primary)
            }
        }
    }
}

// MARK: - Weekly calendar plan: which routine / muscle group on which day.

struct WeekPlanView: View {
    @EnvironmentObject var store: UserStore

    private var exerciseMap: [UUID: Exercise] {
        Dictionary(uniqueKeysWithValues:
            libraryExercises(custom: store.customExercises).map { ($0.id, $0) })
    }

    private func muscleLabel(for routine: Routine) -> String {
        var seen: [String] = []
        for item in routine.items {
            if let g = exerciseMap[item.exerciseId]?.muscleGroup, !seen.contains(g) {
                seen.append(g)
            }
        }
        return seen.isEmpty ? routine.name : seen.joined(separator: " + ")
    }

    var body: some View {
        List {
            Section {
                ForEach(1...7, id: \.self) { weekday in
                    HStack {
                        Text(WeekPlanDay.names[weekday - 1])
                            .font(.subheadline.bold()).frame(width: 40, alignment: .leading)
                        Picker("", selection: Binding(
                            get: { store.plan(forWeekday: weekday)?.routineId },
                            set: { newId in
                                let label = newId.flatMap { id in
                                    store.routines.first { $0.id == id }.map(muscleLabel(for:))
                                }
                                store.setPlan(weekday: weekday, routineId: newId,
                                              muscleLabel: label)
                            })) {
                            Text("Rest").tag(UUID?.none)
                            ForEach(store.routines) { r in
                                Text("\(r.name) (\(muscleLabel(for: r)))").tag(UUID?.some(r.id))
                            }
                        }
                        .labelsHidden()
                    }
                }
            } header: {
                Text("Your week")
            } footer: {
                Text("Open the app tomorrow and Today shows exactly this plan, "
                    + "with last week's weights beside it. Extra exercises added "
                    + "in the live workout are tallied in volume and burn.")
            }
            if store.routines.isEmpty {
                Text("Create a routine first — starter routines arrive with setup.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Weekly plan")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Live session

struct LiveSessionView: View {
    @Environment(\.dismiss) private var dismiss
    var routine: Routine?
    var exerciseMap: [UUID: Exercise]
    var priorSessions: [WorkoutSession]
    var onFinish: (WorkoutSession, [String]) -> Void

    @State private var entries: [SessionEntry]
    @State private var customName: String
    @State private var notes = ""
    @State private var startedAt = Date()
    @State private var showPicker = false
    @State private var showSummary = false
    @State private var restLeft = 0
    @State private var restTotal = 1
    private let ticker = Timer.publish(every: 1, on: .main,
                                       in: .common).autoconnect()

    init(routine: Routine?, exerciseMap: [UUID: Exercise],
         priorSessions: [WorkoutSession],
         onFinish: @escaping (WorkoutSession, [String]) -> Void) {
        self.routine = routine
        self.exerciseMap = exerciseMap
        self.priorSessions = priorSessions
        self.onFinish = onFinish
        _entries = State(initialValue: (routine?.items ?? []).map { item in
            let last = WorkoutStats.lastPerformance(exerciseId: item.exerciseId,
                                                    before: Date(), in: priorSessions)
            return SessionEntry(exerciseId: item.exerciseId,
                                sets: (0..<min(item.targetSets, 5)).map { _ in
                                    WorkoutSet(reps: item.targetReps ?? last?.reps,
                                               weightKg: item.targetWeightKg ?? last?.weightKg)
                                })
        })
        _customName = State(initialValue: routine?.name ?? "Workout")
    }

    private var draft: WorkoutSession {
        WorkoutSession(routineId: routine?.id, routineName: customName,
                       startedAt: startedAt, entries: entries, notes: notes)
    }

    private func prs(for s: WorkoutSession) -> [String] {
        entries.compactMap { entry in
            guard let ex = exerciseMap[entry.exerciseId],
                  WorkoutStats.isPersonalRecord(session: s, exerciseId: entry.exerciseId,
                                                priorSessions: priorSessions),
                  let best = WorkoutStats.bestWeightKg(exerciseId: entry.exerciseId,
                                                        in: [s]) else { return nil }
            return "\(ex.name) \(fmt(best, 0)) kg"
        }
    }

    var body: some View {
        NavigationStack {
            List {
                restSection
                ForEach($entries) { $entry in
                    Section(exerciseMap[entry.exerciseId]?.name ?? "Exercise") {
                        let kind = exerciseMap[entry.exerciseId]?.kind ?? .weighted
                        ForEach($entry.sets) { $set in
                            setRow(set: $set, kind: kind)
                        }
                        HStack {
                            Button("Add set") {
                                Haptics.tap()
                                let last = entry.sets.last
                                entry.sets.append(WorkoutSet(
                                    reps: last?.reps, weightKg: last?.weightKg,
                                    seconds: last?.seconds,
                                    distanceM: last?.distanceM))
                            }
                            Spacer()
                            Button("Remove last") {
                                _ = entry.sets.popLast()
                            }
                            .disabled(entry.sets.isEmpty)
                        }
                        .font(.caption)
                    }
                }
                Section("Notes") {
                    TextField("How did it feel?", text: $notes)
                }
                Section {
                    Button("Add exercise") { showPicker = true }
                }
            }
            .navigationTitle(customName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") { showSummary = true }
                }
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerView(exerciseMap: exerciseMap) { ex in
                    entries.append(SessionEntry(exerciseId: ex.id,
                                                sets: [WorkoutSet()]))
                }
            }
            .sheet(isPresented: $showSummary) {
                SummarySheet(session: draft, prs: prs(for: draft)) {
                    onFinish(draft, prs(for: draft))
                    dismiss()
                }
            }
            .onReceive(ticker) { _ in
                guard restLeft > 0 else { return }
                restLeft -= 1
                if restLeft == 0 { Haptics.success() }
            }
        }
    }

    // MARK: Rest timer: presets, ring, haptic on completion.

    private var restSection: some View {
        Section("Rest") {
            HStack {
                RingView(progress: restTotal > 0
                    ? Double(restLeft) / Double(restTotal) : 0,
                    size: 64, center: "\(restLeft)s", caption: "rest")
                Spacer()
                ForEach([60, 90, 180], id: \.self) { sec in
                    Button("\(sec / 60)\(sec % 60 == 0 ? "" : ".5")m") {
                        Haptics.tap()
                        restTotal = sec
                        restLeft = sec
                    }
                    .buttonStyle(.bordered)
                }
                if restLeft > 0 {
                    Button("Stop") { restLeft = 0 }
                }
            }
        }
    }

    @ViewBuilder
    private func setRow(set: Binding<WorkoutSet>, kind: ExerciseKind) -> some View {
        switch kind {
        case .weighted, .bodyweight:
            HStack {
                TextField("reps", value: set.reps, format: .number)
                    .keyboardType(.decimalPad).frame(width: 60)
                Text("×")
                TextField("kg", value: set.weightKg, format: .number)
                    .keyboardType(.decimalPad).frame(width: 70)
                Spacer()
                if let r = set.wrappedValue.reps,
                   let w = set.wrappedValue.weightKg {
                    Text("\(fmt(r * w, 0)) kg")
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        case .timed:
            HStack {
                TextField("seconds", value: set.seconds, format: .number)
                    .keyboardType(.decimalPad)
                Spacer()
                Text("sec").font(.caption).foregroundStyle(.secondary)
            }
        case .cardio:
            HStack {
                TextField("min", value: set.seconds, format: .number)
                    .keyboardType(.decimalPad).frame(width: 60)
                TextField("m", value: set.distanceM, format: .number)
                    .keyboardType(.decimalPad).frame(width: 80)
                Spacer()
            }
        }
    }
}

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    var exerciseMap: [UUID: Exercise]
    var onPick: (Exercise) -> Void
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(filtered) { ex in
                Button {
                    onPick(ex)
                    dismiss()
                } label: {
                    VStack(alignment: .leading) {
                        Text(ex.name).foregroundStyle(.primary)
                        Text("\(ex.muscleGroup) · \(ex.equipment)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .searchable(text: $query)
            .navigationTitle("Add exercise")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var filtered: [Exercise] {
        let all = exerciseMap.values.sorted { $0.name < $1.name }
        guard !query.isEmpty else { return all }
        return all.filter { $0.name.lowercased().contains(query.lowercased()) }
    }
}

/// Completion feedback: what happened, then one commit button.
struct SummarySheet: View {
    @Environment(\.dismiss) private var dismiss
    var session: WorkoutSession
    var prs: [String]
    var onSave: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    LabeledContent("Volume", value: "\(fmt(session.volume, 0)) kg")
                    LabeledContent("Sets", value: "\(session.entries.reduce(0) { $0 + $1.sets.count })")
                    LabeledContent("Duration", value: duration)
                }
                if !prs.isEmpty {
                    Section("Personal records") {
                        ForEach(prs, id: \.self) { pr in
                            Label(pr, systemImage: "trophy.fill")
                                .foregroundStyle(.yellow)
                        }
                    }
                }
            }
            .navigationTitle("Workout complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep editing") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var duration: String {
        let mins = max(1, Int(Date().timeIntervalSince(session.startedAt) / 60))
        return "\(mins) min"
    }
}
