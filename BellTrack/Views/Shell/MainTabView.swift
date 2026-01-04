import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {

            // TAB 1 – Workouts
            NavigationStack {
                WorkoutsListView()
            }
            .tabItem {
                Label("Workouts", systemImage: "list.bullet")
            }

            // TAB 2 – Insights
            NavigationStack {
                ProgressListView()
            }
            .tabItem {
                Label("Progress", systemImage: "chart.xyaxis.line")
            }

            // TAB 3 – Settings
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}
