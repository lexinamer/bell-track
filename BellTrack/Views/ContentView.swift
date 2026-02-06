import SwiftUI

struct ContentView: View {

    @EnvironmentObject var authService: AuthService

    var body: some View {
        if authService.user != nil {
            TabView {

                NavigationStack {
                    TrainingView()
                }
                .tabItem {
                    Image(systemName: "figure.strengthtraining.traditional")
                    Text("Train")
                }

                NavigationStack {
                    InsightsView()
                }
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Insights")
                }

                NavigationStack {
                    ExercisesView()
                }
                .tabItem {
                    Image(systemName: "dumbbell")
                    Text("Exercises")
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
