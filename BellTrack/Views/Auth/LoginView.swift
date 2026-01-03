import SwiftUI
import Foundation

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var showSignUp = false
    @State private var showPasswordReset = false
    @State private var resetEmail = ""
    @State private var resetMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.md) {
                Spacer()
                    .frame(height: 60)
                
                HStack(spacing: Spacing.sm) {
                    Image("AppLogo")
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 40, height: 50)
                    
                    Text("BELL TRACK")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.brand.primary)
                        .kerning(2.8)
                }
                
                Text("Your workout journal, simplified.")
                        .font(.system(size: Typography.lg))
                        .foregroundColor(Color.brand.textPrimary)
                        .kerning(0.3)
                
                Spacer()
                    .frame(height: 40)
                
                VStack(spacing: Spacing.md) {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .disableAutocorrection(true)
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
                            .font(.system(size: Typography.sm))
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

                    Button("Forgot Password?") {
                        showPasswordReset = true
                    }
                    .font(.system(size: Typography.sm))
                    .foregroundColor(Color.brand.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)

                }
                .padding(.horizontal, Spacing.lg)
                
                Spacer()
                    .frame(height: 30)
                
                Button(action: { showSignUp = true }) {
                    Text("Don't have an account? Sign Up")
                        .foregroundColor(Color.brand.primary)
                }
            }
            .background(Color.brand.surface)
            .sheet(isPresented: $showSignUp) {
                SignUpView()
            }
            .sheet(isPresented: $showPasswordReset) {
                PasswordResetView()
            }
        }
    }
    
    private func signIn() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            errorMessage = "Please enter both email and password."
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                try await authService.signIn(email: trimmedEmail, password: trimmedPassword)
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Invalid email or password"
                    isLoading = false
                }
            }
        }
    }
}
