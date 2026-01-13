import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        Group {
            if authService.user == nil {
                LoginView()
            } else {
                signedInShell
            }
        }
    }

    private var signedInShell: some View {
        NavigationStack {
            ZStack {
                Color.brand.background.ignoresSafeArea()
                HomeView()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
