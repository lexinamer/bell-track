import SwiftUI

struct ContentView: View {

    @EnvironmentObject var authService: AuthService

    var body: some View {
        if authService.user != nil {
            TabView {

                NavigationStack {
                    BlocksView()
                }
                .tabItem {
                    Image(systemName: "square.stack.3d.up")
                    Text("Blocks")
                }

                NavigationStack {
                    WorkoutsView()
                }
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Workouts")
                }
                
                NavigationStack {
                    InsightsView()
                }
                .tabItem {
                    Image(systemName: "chart.xyaxis.line")
                    Text("Insights")
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
