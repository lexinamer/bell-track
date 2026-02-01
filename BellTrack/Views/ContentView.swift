import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        Group {
            if authService.user != nil {
                WorkoutsView()
            } else {
                LoginView()
            }
        }
    }
}
