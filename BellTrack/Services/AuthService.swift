import Foundation
import FirebaseAuth
import Combine

class AuthService: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        self.user = Auth.auth().currentUser
        self.isAuthenticated = self.user != nil

        // Keep user state in sync with Firebase
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            self.user = user
            self.isAuthenticated = (user != nil)
        }
    }
    
    func signUp(email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        await MainActor.run {
            self.user = result.user
            self.isAuthenticated = true
        }
    }
    
    func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        await MainActor.run {
            self.user = result.user
            self.isAuthenticated = true
        }
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
        self.user = nil
        self.isAuthenticated = false
    }
    
    deinit {
        if let handle = authStateListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
