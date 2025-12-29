import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var showSignUp = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                Spacer()
                
                // Logo would go here
                Text("Bell Track")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color.brand.primary)
                
                Spacer()
                
                VStack(spacing: Spacing.md) {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(Color.brand.surface)
                        .cornerRadius(CornerRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .stroke(Color.brand.border, lineWidth: 1)
                        )
                    
                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color.brand.surface)
                        .cornerRadius(CornerRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .stroke(Color.brand.border, lineWidth: 1)
                        )
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(Color.brand.destructive)
                    }
                    
                    Button(action: signIn) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Log In")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brand.primary)
                    .foregroundColor(.white)
                    .cornerRadius(CornerRadius.md)
                    .disabled(isLoading)
                }
                .padding(.horizontal, Spacing.lg)
                
                Spacer()
                
                Button(action: { showSignUp = true }) {
                    Text("Don't have an account? Sign Up")
                        .foregroundColor(Color.brand.primary)
                }
            }
            .background(Color.brand.background)
            .sheet(isPresented: $showSignUp) {
                SignUpView()
            }
        }
    }
    
    private func signIn() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                try await authService.signIn(email: email, password: password)
            } catch {
                await MainActor.run {
                    errorMessage = "Invalid email or password"
                    isLoading = false
                }
            }
        }
    }
}
