import SwiftUI

struct ContentView: View {

    @EnvironmentObject var authService: AuthService

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            if authService.user != nil {
                NavigationStack {
                    WorkoutListView()
                }
            } else {
                LoginView()
            }
        }
    }
}
