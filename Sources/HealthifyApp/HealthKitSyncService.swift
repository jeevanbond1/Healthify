import Foundation
import Combine
import HealthKit
import HealthifyCore

// MARK: - Apple Health import (read-only)
//
// Pulls body, nutrition and workout data out of HealthKit — including
// readings your scale app (e.g. HealthU+) writes there — and merges
// them losslessly: per-type anchors for incremental reads, HealthKit
// UUIDs for dedupe, deletions honored, manual entries never touched.

@MainActor
public final class HealthKitSyncService: ObservableObject {
    public enum Status: String {
        case idle, syncing, connected, denied, unavailable, error
    }

    @Published public private(set) var status: Status = .idle
    @Published public private(set) var lastSync: Date?
    @Published public private(set) var lastError: String?
    @Published public private(set) var lastReport: String?

    public var bodyEnabled: Bool {
        get { defaults.bool(forKey: Keys.group(HealthDataGroup.body), default: true) }
        set { defaults.set(newValue, forKey: Keys.group(HealthDataGroup.body)) }
    }
    public var nutritionEnabled: Bool {
        get { defaults.bool(forKey: Keys.group(HealthDataGroup.nutrition), default: true) }
        set { defaults.set(newValue, forKey: Keys.group(HealthDataGroup.nutrition)) }
    }
    public var activityEnabled: Bool {
        get { defaults.bool(forKey: Keys.group(HealthDataGroup.activity), default: true) }
        set { defaults.set(newValue, forKey: Keys.group(HealthDataGroup.activity)) }
    }

    private let store = HKHealthStore()
    private let defaults = UserDefaults.standard
    private var observers: [HKObserverQuery] = []

    private enum Keys {
        static let connected = "Healthify.hk.connected"
        static let lastSync = "Healthify.hk.lastSync"
        static func anchor(_ typeKey: String) -> String { "Healthify.hk.anchor.\(typeKey)" }
        static func group(_ group: HealthDataGroup) -> String { "Healthify.hk.group.\(group.rawValue)" }
    }

    public init() {
        if defaults.bool(forKey: Keys.connected) { status = .connected }
        lastSync = defaults.object(forKey: Keys.lastSync) as? Date
    }

    public var isSupported: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        var out = Set<HKObjectType>()
        for kind in HealthDataKind.allCases where isKindEnabled(kind) {
            if kind == .workout {
                out.insert(HKObjectType.workoutType())
            } else if let q = HKObjectType.quantityType(forIdentifier: .init(rawValue: kind.hkIdentifier)) {
                out.insert(q)
            }
        }
        return out
    }

    private func isKindEnabled(_ kind: HealthDataKind) -> Bool {
        switch kind.group {
        case .body: return bodyEnabled
        case .nutrition: return nutritionEnabled
        case .activity: return activityEnabled
        }
    }

    // MARK: - Authorization

    public func requestAccess() async {
        guard isSupported else { status = .unavailable; return }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            defaults.set(true, forKey: Keys.connected)
            status = .connected
            lastError = nil
        } catch {
            status = .denied
            lastError = error.localizedDescription
        }
    }

    // MARK: - Anchored fetch

    private nonisolated static func storedAnchor(for typeKey: String) -> HKQueryAnchor? {
        let d = UserDefaults.standard
        guard let data = d.data(forKey: Keys.anchor(typeKey)) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    private nonisolated static func saveAnchor(_ anchor: HKQueryAnchor?, for typeKey: String) {
        guard let anchor,
              let data = try? NSKeyedArchiver.archivedData(
                withRootObject: anchor, requiringSecureCoding: true) else { return }
        UserDefaults.standard.set(data, forKey: Keys.anchor(typeKey))
    }

    private struct FetchResult {
        var samples: [HealthSample] = []
        var workouts: [HealthWorkout] = []
        var deletedUUIDs: Set<String> = []
    }

    private func fetch(kind: HealthDataKind) async throws -> FetchResult {
        let typeKey = kind.rawValue
        if kind == .workout {
            let type = HKObjectType.workoutType()
            return try await withCheckedThrowingContinuation { cont in
                let q = HKAnchoredObjectQuery(
                    type: type, predicate: nil,
                    anchor: Self.storedAnchor(for: typeKey), limit: HKObjectQueryNoLimit
                ) { _, samples, deleted, newAnchor, error in
                    if let error { cont.resume(throwing: error); return }
                    var r = FetchResult()
                    r.workouts = (samples as? [HKWorkout] ?? []).compactMap(Self.mapWorkout)
                    r.deletedUUIDs = Set((deleted ?? []).map { $0.uuid.uuidString })
                    Self.saveAnchor(newAnchor, for: typeKey)
                    cont.resume(returning: r)
                }
                self.store.execute(q)
            }
        }
        guard let qtype = HKObjectType.quantityType(
            forIdentifier: HKQuantityTypeIdentifier(rawValue: kind.hkIdentifier)) else {
            return FetchResult()
        }
        return try await withCheckedThrowingContinuation { cont in
            let q = HKAnchoredObjectQuery(
                type: qtype, predicate: nil,
                anchor: Self.storedAnchor(for: typeKey), limit: HKObjectQueryNoLimit
            ) { _, samples, deleted, newAnchor, error in
                if let error { cont.resume(throwing: error); return }
                var r = FetchResult()
                r.samples = (samples as? [HKQuantitySample] ?? []).compactMap {
                    Self.mapSample($0, kind: kind)
                }
                r.deletedUUIDs = Set((deleted ?? []).map { $0.uuid.uuidString })
                Self.saveAnchor(newAnchor, for: typeKey)
                cont.resume(returning: r)
            }
            self.store.execute(q)
        }
    }

    // MARK: - Conversion (HealthKit values -> canonical units)

    private nonisolated static func unit(for kind: HealthDataKind) -> HKUnit {
        switch kind {
        case .bodyMass, .leanBodyMass: return .gramUnit(with: .kilo)
        case .bodyFatPercentage: return .percent()
        case .bodyMassIndex: return .count()
        case .height: return .meter()
        case .dietaryEnergy: return .kilocalorie()
        case .dietaryProtein, .dietaryCarbs, .dietaryFat,
             .dietaryFiber, .dietarySugar: return .gram()
        case .dietarySodium, .dietaryPotassium, .dietaryCalcium,
             .dietaryIron, .dietaryVitaminC: return .gramUnit(with: .milli)
        case .dietaryWater: return .literUnit(with: .milli)
        case .workout: return .count()
        }
    }

    private nonisolated static func mapSample(_ sample: HKQuantitySample, kind: HealthDataKind) -> HealthSample? {
        let bundle = sample.sourceRevision.source.bundleIdentifier
        if bundle == Bundle.main.bundleIdentifier { return nil } // never re-import ourselves
        let meta = sample.metadata
        let food = meta?[HKMetadataKeyFoodType] as? String
        return HealthSample(
            hkUUID: sample.uuid.uuidString, typeKey: kind.rawValue,
            startDate: sample.startDate, endDate: sample.endDate,
            value: sample.quantity.doubleValue(for: unit(for: kind)),
            sourceBundle: bundle,
            sourceName: sample.sourceRevision.source.name,
            foodName: food)
    }

    private nonisolated static func mapWorkout(_ workout: HKWorkout) -> HealthWorkout? {
        let bundle = workout.sourceRevision.source.bundleIdentifier
        if bundle == Bundle.main.bundleIdentifier { return nil }
        let energy = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
        return HealthWorkout(
            hkUUID: workout.uuid.uuidString,
            activityName: Self.activityName(for: workout.workoutActivityType),
            startDate: workout.startDate, endDate: workout.endDate,
            totalEnergyKcal: energy, sourceBundle: bundle,
            sourceName: workout.sourceRevision.source.name)
    }

    private nonisolated static func activityName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .traditionalStrengthTraining, .functionalStrengthTraining,
             .coreTraining: return "Strength training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .stairClimbing: return "Stair climbing"
        case .hiking: return "Hiking"
        case .dance, .danceInspiredTraining: return "Dance"
        case .tennis: return "Tennis"
        case .pilates: return "Pilates"
        case .boxing: return "Boxing"
        case .soccer: return "Soccer"
        case .basketball: return "Basketball"
        default: return "Workout"
        }
    }

    // MARK: - Sync + observe

    public func sync(into store: UserStore) async {
        guard isSupported else { status = .unavailable; return }
        status = .syncing
        lastError = nil
        do {
            var bodyMass: [HealthSample] = []
            var bodyFat: [HealthSample] = []
            var lean: [HealthSample] = []
            var bmi: [HealthSample] = []
            var dietary: [HealthSample] = []
            var water: [HealthSample] = []
            var height: [HealthSample] = []
            var workouts: [HealthWorkout] = []
            var deleted = Set<String>()
            for kind in HealthDataKind.allCases where isKindEnabled(kind) {
                let r = try await fetch(kind: kind)
                deleted.formUnion(r.deletedUUIDs)
                switch kind.group {
                case .body:
                    switch kind {
                    case .bodyMass: bodyMass = r.samples
                    case .bodyFatPercentage: bodyFat = r.samples
                    case .leanBodyMass: lean = r.samples
                    case .bodyMassIndex: bmi = r.samples
                    case .height: height = r.samples
                    default: break
                    }
                case .nutrition:
                    if kind == .dietaryWater { water = r.samples }
                    else { dietary += r.samples }
                case .activity:
                    if kind == .workout { workouts = r.workouts }
                }
            }
            let report = store.applyHealthImport(
                weights: HealthSyncMapper.weightEntries(
                    bodyMass: bodyMass, bodyFat: bodyFat, leanMass: lean, bmi: bmi),
                diary: HealthSyncMapper.diaryEntries(from: dietary),
                sessions: HealthSyncMapper.workoutSessions(from: workouts),
                water: water, height: height, deletedUUIDs: deleted)
            lastSync = Date()
            defaults.set(lastSync, forKey: Keys.lastSync)
            status = .connected
            lastReport = report
        } catch {
            status = .error
            lastError = error.localizedDescription
        }
    }

    /// Live updates while the app runs. No background-delivery entitlement
    /// needed — a full anchored sync also runs on every app foreground.
    public func startObservers(onUpdate: @escaping () -> Void) {
        stopObservers()
        for kind in HealthDataKind.allCases where isKindEnabled(kind) {
            let type: HKSampleType? = kind == .workout
                ? HKObjectType.workoutType()
                : HKObjectType.quantityType(
                    forIdentifier: HKQuantityTypeIdentifier(rawValue: kind.hkIdentifier))
            guard let type else { continue }
            let q = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
                defer { completion() }
                guard error == nil else { return }
                onUpdate()
            }
            store.execute(q)
            observers.append(q)
        }
    }

    public func stopObservers() {
        observers.forEach(store.stop)
        observers.removeAll()
    }
}

// MARK: - UserDefaults bool with default (no extra model churn)

private extension UserDefaults {
    func bool(forKey key: String, default fallback: Bool) -> Bool {
        object(forKey: key) == nil ? fallback : bool(forKey: key)
    }
}
