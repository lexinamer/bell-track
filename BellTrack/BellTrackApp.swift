import SwiftUI
import FirebaseCore

@main
struct BellTrackApp: App {
    @StateObject private var authService = AuthService()

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
        }
    }
}
