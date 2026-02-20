import SwiftUI

struct ContentView: View {

    @EnvironmentObject var authService: AuthService

    var body: some View {
        ZStack {
            Color.brand.background
                .ignoresSafeArea()

            if authService.user != nil {
                TabView {

                    NavigationStack {
                        TrainView()
                    }
                    .tabItem {
                        Image(systemName: "figure.strengthtraining.traditional")
                        Text("Train")
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
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                }
                .task {
                    try? await FirestoreService.shared.seedDefaultExercisesIfNeeded()
                }
            } else {
                LoginView()
            }
        }
    }
}
