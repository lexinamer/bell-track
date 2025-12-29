import SwiftUI
import FirebaseCore

@main
struct BellTrackApp: App {
    @StateObject private var authService = AuthService()
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
        }
    }
}
