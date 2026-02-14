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
                    Image(systemName: "list.bullet.clipboard")
                    Text("Training")
                }
                
                NavigationStack {
                    InsightsView()
                }
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Insights")
                }
                
                NavigationStack {
//                    HistoryView()
                }
                .tabItem {
                    Label("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                }

                NavigationStack {
                    SettingsView()
                }
                .tabItem {
                    Image(systemName: "gearshape")
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
