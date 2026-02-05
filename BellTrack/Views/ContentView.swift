import SwiftUI

struct ContentView: View {

    @EnvironmentObject var authService: AuthService

    var body: some View {
        if authService.user != nil {
            TabView {

                NavigationStack {
                    WorkoutsView()
                }
                .tabItem {
                    Image(systemName: "doc.plaintext")
                    Text("Workouts")
                }

                NavigationStack {
                    BlocksView()
                }
                .tabItem {
                    Image(systemName: "cube")
                    Text("Blocks")
                }

                NavigationStack {
                    ExercisesView()
                }
                .tabItem {
                    Image(systemName: "dumbbell")
                    Text("Exercises")
                }

                NavigationStack {
                    InsightsView()
                }
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Insights")
                }

                NavigationStack {
                    SettingsView()
                }
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
            }
            .tint(Color.brand.primary)
            .background(Color.brand.background)
        } else {
            LoginView()
        }
    }
}
