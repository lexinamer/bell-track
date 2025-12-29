import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        if authService.isAuthenticated {
            Text("Main App Goes Here")
                .font(.largeTitle)
        } else {
            LoginView()
        }
    }
}
