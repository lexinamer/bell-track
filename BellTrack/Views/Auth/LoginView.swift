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

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Space.md) {

                // Push content down slightly (feels centered, not top-heavy)
                Spacer()
                    .frame(height: 20)

                // Logo + title
                HStack(spacing: Theme.Space.sm) {
                    Image("AppLogo")
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 40, height: 50)

                    Text("BELL TRACK")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.brand.primary)
                        .kerning(2.8)
                }

                Text("A simple way to track training blocks.")
                    .font(.system(size: Theme.TypeSize.lg))
                    .foregroundColor(Color.brand.textPrimary)
                    .kerning(0.3)

                Spacer()
                    .frame(height: 20)

                // FORM
                VStack(spacing: Theme.Space.md) {

                    // Email
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .disableAutocorrection(true)
                        .padding()
                        .background(Color.brand.surface)
                        .cornerRadius(Theme.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .stroke(Color.brand.border, lineWidth: 1)
                        )

                    // Password
                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color.brand.surface)
                        .cornerRadius(Theme.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .stroke(Color.brand.border, lineWidth: 1)
                        )

                    // Error
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: Theme.TypeSize.sm))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Log In button (close to password — intentionally)
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
                    .cornerRadius(Theme.Radius.md)
                    .disabled(isLoading)

                    // Forgot password
                    Button("Forgot Password?") {
                        showPasswordReset = true
                    }
                    .font(.system(size: Theme.TypeSize.md))
                    .foregroundColor(Color.brand.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, Theme.Space.lg)

                Spacer()
                    .frame(height: 20)

                // Sign up
                Button {
                    showSignUp = true
                } label: {
                    Text("Don't have an account? Sign Up")
                        .foregroundColor(Color.brand.primary)
                }
            }
            .background(Color.brand.surface)
            .sheet(isPresented: $showSignUp) {
                SignupView()
            }
            .sheet(isPresented: $showPasswordReset) {
                PasswordResetView()
            }
        }
    }

    // MARK: - Actions

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
                try await authService.signIn(
                    email: trimmedEmail,
                    password: trimmedPassword
                )
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
