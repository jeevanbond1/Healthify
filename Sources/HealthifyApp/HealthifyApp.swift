import SwiftUI
import HealthifyCore

@main
struct HealthifyApp: App {
    @StateObject private var store = UserStore()
    @StateObject private var healthSync = HealthKitSyncService()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            Group {
                if store.onboarded {
                    ContentView()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(store)
            .environmentObject(healthSync)
            .task {
                healthSync.startObservers {
                    Task { await healthSync.sync(into: store) }
                }
            }
            .onChange(of: phase) { _, newPhase in
                if newPhase == .active, healthSync.status == .connected {
                    Task { await healthSync.sync(into: store) }
                }
            }
        }
    }
}

/// Specific labels for specific contents. No vague "Home".
struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
            DiaryView()
                .tabItem { Label("Diary", systemImage: "book.pages") }
            FoodsView()
                .tabItem { Label("Foods", systemImage: "magnifyingglass") }
            WorkoutsView()
                .tabItem { Label("Workouts", systemImage: "dumbbell") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .buttonStyle(PressableStyle())
    }
}
