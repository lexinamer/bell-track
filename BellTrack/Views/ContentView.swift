import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        if authService.isAuthenticated {
            WorkoutsListView()
        } else {
            LoginView()
        }
    }
}
