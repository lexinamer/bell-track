import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainTabView()
            } else {
                NavigationStack {
                    LoginView()
                }
            }
        }
    }
}
