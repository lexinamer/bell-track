import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        Group {
            if authService.user == nil {
                LoginView()
            } else {
                MainTabView()
            }
        }
    }
}
