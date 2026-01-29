import SwiftUI

struct ContentView: View {

    @EnvironmentObject private var authService: AuthService

    @State private var selectedTab: Tab = .home
    @State private var showLogWorkout = false

    var body: some View {
        Group {
            if authService.user != nil {
                mainApp
            } else {
                LoginView()
            }
        }
    }

    private var mainApp: some View {
        TabView(selection: $selectedTab) {

            NavigationStack {
                HomeView(showLogWorkout: $showLogWorkout)
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(Tab.home)

            NavigationStack {
                TrainingView()
            }
            .tabItem {
                Label("Training", systemImage: "list.bullet")
            }
            .tag(Tab.training)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(Tab.settings)
        }
        .sheet(isPresented: $showLogWorkout) {
            LogWorkoutView()
        }
    }
}

enum Tab {
    case home
    case training
    case settings
}
