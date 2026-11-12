import SwiftUI
import UniformTypeIdentifiers
import HealthifyCore

// MARK: - File document for backup (.json) and CSV export.

struct DataDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let d = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = d
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        .init(regularFileWithContents: data)
    }
}

// MARK: - Settings: goals, units, backup/restore, about. No account section.

struct SettingsView: View {
    @EnvironmentObject var store: UserStore
    @EnvironmentObject var health: HealthKitSyncService
    @State private var showGoalEdit = false
    @State private var showExport = false
    @State private var showCSV = false
    @State private var showImport = false
    @State private var exportDoc = DataDocument()
    @State private var exportName = "healthify-backup.json"
    @State private var exportType: UTType = .json
    @State private var pendingBackup: BackupFile?
    @State private var pendingRaw: Data?
    @State private var showModePicker = false
    @State private var report: [String]?
    @State private var importError: String?
    @State private var showDeleteAll = false

    var body: some View {
        NavigationStack {
            List {
                Section("Goals") {
                    LabeledContent("Calories",
                                   value: "\(fmt(store.goal.targetKcal)) kcal")
                    LabeledContent("Protein", value: "\(fmt(store.goal.proteinG)) g")
                    LabeledContent("Carbs", value: "\(fmt(store.goal.carbsG)) g")
                    LabeledContent("Fat", value: "\(fmt(store.goal.fatG)) g")
                    Button("Edit goals") { showGoalEdit = true }
                }
                Section("Units") {
                    Picker("Units", selection: unitsBinding) {
                        Text("Metric (kg, g)").tag(Units.metric)
                        Text("Imperial (lb, oz)").tag(Units.imperial)
                    }
                }
                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(healthStatusText).foregroundStyle(.secondary)
                    }
                    if health.status != .connected {
                        Button("Connect Apple Health") {
                            Task {
                                await health.requestAccess()
                                if health.status == .connected {
                                    await health.sync(into: store)
                                }
                            }
                        }
                    } else {
                        Toggle("Body & scale readings", isOn: hkToggle(\.bodyEnabled))
                        Toggle("Nutrition", isOn: hkToggle(\.nutritionEnabled))
                        Toggle("Workouts & activity", isOn: hkToggle(\.activityEnabled))
                        Button("Sync now") {
                            Task { await health.sync(into: store) }
                        }
                        .disabled(health.status == .syncing)
                        if let last = health.lastSync {
                            Text("Last synced \(last.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if let rep = health.lastReport {
                            Text(rep).font(.caption).foregroundStyle(.secondary)
                        }
                        if let err = health.lastError {
                            Text(err).font(.caption).foregroundStyle(.red)
                        }
                    }
                    NavigationLink("Get readings from my scale") {
                        HealthScaleHelpView()
                    }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Read-only. Healthify pulls weight, body composition, "
                        + "nutrition, water and workouts into this phone so no "
                        + "data point is lost. Nothing is ever written back or uploaded.")
                }
                Section {
                    Button("Export backup file") {
                        do {
                            exportDoc = DataDocument(data: try store.exportBackup())
                            exportName = "healthify-backup-\(dayString()).json"
                            exportType = .json
                            showExport = true
                        } catch {
                            importError = error.localizedDescription
                        }
                    }
                    Button("Import backup file") { showImport = true }
                    Button("Export diary CSV") {
                        let csv = store.diaryCSV()
                        exportDoc = DataDocument(data: Data(csv.utf8))
                        exportName = "healthify-diary-\(dayString()).csv"
                        exportType = UTType(filenameExtension: "csv") ?? .commaSeparatedText
                        showCSV = true
                    }
                    if UserDefaults.standard.data(forKey: "Healthify.lastSnapshot") != nil {
                        Button("Undo last import") {
                            do {
                                try store.undoLastImport()
                                Haptics.success()
                                report = ["Restored the snapshot taken before the last import."]
                            } catch {
                                importError = error.localizedDescription
                            }
                        }
                    }
                } header: {
                    Text("Backup & restore")
                } footer: {
                    Text("Export saves one file you keep — in Files, iCloud Drive, "
                        + "or anywhere you choose. If this app is deleted, only an "
                        + "exported file can bring your data back.")
                }
                Section {
                    Button("Delete all my data", role: .destructive) {
                        showDeleteAll = true
                    }
                }
                Section("About") {
                    Text("Healthify (working title) · local-only diet + gym tracker")
                        .font(.caption)
                    Text("Food data: USDA FoodData Central (public domain) and "
                        + "Open Food Facts (ODbL — attribution in this screen). "
                        + "Curated Indian foods are estimates, marked in the app.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("General wellness guidance only — not medical advice. "
                        + "No account, no network calls, no data leaves this phone.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .keyboardDoneToolbar()
            .navigationTitle("Settings")
            .sheet(isPresented: $showGoalEdit) { GoalEditSheet() }
            .fileExporter(isPresented: $showExport, document: exportDoc,
                          contentType: exportType,
                          defaultFilename: exportName) { _ in }
            .fileExporter(isPresented: $showCSV, document: exportDoc,
                          contentType: exportType,
                          defaultFilename: exportName) { _ in }
            .fileImporter(isPresented: $showImport,
                          allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .confirmationDialog("Apply backup", isPresented: $showModePicker,
                                titleVisibility: .visible) {
                Button("Replace all my data") { applyPending(mode: .replace) }
                Button("Merge with my data") { applyPending(mode: .merge) }
            } message: {
                Text(pendingSummary)
            }
            .alert("Import result", isPresented: Binding(
                get: { report != nil },
                set: { if !$0 { report = nil } })) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(report?.joined(separator: "\n") ?? "")
                }
            .alert("Import failed", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } })) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(importError ?? "")
                }
            .confirmationDialog("Delete everything?", isPresented: $showDeleteAll,
                                titleVisibility: .visible) {
                Button("Delete all data", role: .destructive) {
                    store.resetAll()
                }
            } message: {
                Text("Diary, workouts, foods, goals — everything on this phone. "
                    + "This cannot be undone without an exported backup file.")
            }
        }
    }

    private var unitsBinding: Binding<Units> {
        Binding(
            get: { store.settings.units },
            set: {
                var s = store.settings
                s.units = $0
                store.settings = s
                store.save()
            })
    }

    private var healthStatusText: String {
        switch health.status {
        case .idle: return "Not connected"
        case .syncing: return "Syncing…"
        case .connected: return "Connected"
        case .denied: return "Permission needed"
        case .unavailable: return "Not available on this device"
        case .error: return "Sync failed"
        }
    }

    private func hkToggle(_ keyPath: ReferenceWritableKeyPath<HealthKitSyncService, Bool>) -> Binding<Bool> {
        Binding(
            get: { health[keyPath: keyPath] },
            set: { health[keyPath: keyPath] = $0 })
    }

    private var pendingSummary: String {
        guard let p = pendingBackup else { return "" }
        let bits = p.counts.sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        return "Backup from \(p.exportedAt.formatted(date: .abbreviated, time: .shortened)). \(bits)"
    }

    private func handleImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            guard url.startAccessingSecurityScopedResource() else {
                importError = "Could not access the file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            let data = try Data(contentsOf: url)
            pendingRaw = data
            pendingBackup = try BackupCodec.validate(data)
            showModePicker = true
        } catch {
            Haptics.error()
            importError = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
    }

    private func applyPending(mode: BackupMode) {
        guard let data = pendingRaw else { return }
        do {
            report = try store.importBackup(data, mode: mode)
            Haptics.success()
        } catch {
            Haptics.error()
            importError = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
        pendingRaw = nil
        pendingBackup = nil
    }
}

// MARK: - Goal editing reuses the same engine + safety floors as onboarding.

struct GoalEditSheet: View {
    @EnvironmentObject var store: UserStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = GoalProfile()

    var body: some View {
        NavigationStack {
            Form {
                Section("You") {
                    TextField("Name", text: Binding(
                        get: { draft.displayName ?? "" },
                        set: { draft.displayName = $0 }))
                    HStack {
                        Text("Current weight (kg)"); Spacer()
                        TextField("kg", value: $draft.weightKg, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing).frame(width: 80)
                    }
                    HStack {
                        Text("Target weight (kg)"); Spacer()
                        TextField("kg", value: Binding(
                            get: { draft.targetWeightKg ?? draft.weightKg },
                            set: { draft.targetWeightKg = $0 }), format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing).frame(width: 80)
                    }
                }
                Picker("Activity", selection: $draft.activity) {
                    ForEach(ActivityLevel.allCases, id: \.self) { a in
                        Text(a.label).tag(a)
                    }
                }
                Section("Pace") {
                    Picker("Pace", selection: $draft.weeklyKg) {
                        Text("Gentle").tag(0.25)
                        Text("Steady").tag(0.5)
                        Text("Faster").tag(0.75)
                        Text("Aggressive").tag(1.0)
                    }
                    .pickerStyle(.segmented)
                    Text("\(fmt(draft.weeklyKg, 2)) kg / week")
                        .font(.caption).foregroundStyle(.secondary)
                }
                let preview = GoalEngine.retarget(draft)
                Section("Targets") {
                    LabeledContent("Calories", value: "\(fmt(preview.targetKcal)) kcal")
                    LabeledContent("Protein", value: "\(fmt(preview.proteinG)) g")
                    LabeledContent("Carbs", value: "\(fmt(preview.carbsG)) g")
                    LabeledContent("Fat", value: "\(fmt(preview.fatG)) g")
                    LabeledContent("Estimated time",
                                   value: "\(GoalEngine.estimatedDays(currentKg: draft.weightKg, targetKg: draft.targetWeightKg, weeklyKg: draft.weeklyKg)) days")
                }
            }
            .keyboardDoneToolbar()
            .navigationTitle("Edit goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Haptics.commit()
                        store.updateGoal(draft)
                        dismiss()
                    }
                }
            }
            .onAppear { draft = store.goal }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
