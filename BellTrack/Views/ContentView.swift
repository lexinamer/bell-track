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
                    Image(systemName: "square.stack.3d.up")
                    Text("Training")
                }
                
                NavigationStack {
                    HistoryView()
                }
                .tabItem {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("History")
                }
                
                NavigationStack {
                    InsightsView()
                }
                .tabItem {
                    Image(systemName: "chart.xyaxis.line")
                    Text("Insights")
                }
                
                NavigationStack {
                    ExercisesView()
                }
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Exercises")
                }

                NavigationStack {
                    SettingsView()
                }
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
            }
            .background(Color.brand.background)
            .task {
                try? await FirestoreService().seedDefaultExercisesIfNeeded()
            }
        } else {
            LoginView()
        }
    }
}
