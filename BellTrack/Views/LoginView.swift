import SwiftUI

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
                    Image("BTLogo")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(Color.brand.secondary)
                        .frame(width: 40, height: 50)
                    
                    Text("BELL TRACK")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.brand.secondary)
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
                        .padding()
                        .background(Color.brand.surface)
                        .cornerRadius(CornerRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .stroke(Color.brand.border, lineWidth: 1)
                        )
                    
                    // Password field
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

                    // Log In button
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
                    .background(Color.brand.secondary)
                    .foregroundColor(.white)
                    .cornerRadius(CornerRadius.md)
                    .disabled(isLoading)

                    // Forgot Password button
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
                        .foregroundColor(Color.brand.secondary)
                }
            }
            .background(Color.brand.background)
            .sheet(isPresented: $showSignUp) {
                SignUpView()
            }
            .sheet(isPresented: $showPasswordReset) {
                PasswordResetView()
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
