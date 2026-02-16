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
            ZStack {
                Color.brand.background
                    .ignoresSafeArea()

                VStack(spacing: Theme.Space.md) {

                Spacer()
                    .frame(height: Theme.Space.mdp)

                // Logo + title
                HStack(spacing: Theme.Space.sm) {
                    Image("AppLogo")
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 40, height: 50)

                    Text("BELL TRACK")
                        .font(Theme.Font.pageTitle)
                        .foregroundColor(Color.brand.primary)
                        .kerning(2.8)
                }

                Text("A simple way to track workouts.")
                    .font(.system(size: Theme.TypeSize.lg))
                    .foregroundColor(Color.brand.textPrimary)
                    .kerning(0.3)

                Spacer()
                    .frame(height: Theme.Space.mdp)

                // FORM
                VStack(spacing: Theme.Space.md) {

                    // Email
                    TextField("", text: $email, prompt: Text("Email").foregroundColor(Color.brand.textSecondary))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .disableAutocorrection(true)
                        .padding()
                        .foregroundColor(Color.brand.textPrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .stroke(Color.brand.border, lineWidth: 1)
                        )

                    // Password
                    SecureField("", text: $password, prompt: Text("Password").foregroundColor(Color.brand.textSecondary))
                        .padding()
                        .foregroundColor(Color.brand.textPrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .stroke(Color.brand.border, lineWidth: 1)
                        )

                    // Error
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: Theme.TypeSize.sm))
                            .foregroundColor(Color.brand.destructive)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                    .frame(height: Theme.Space.mdp)

                // Sign up
                Button {
                    showSignUp = true
                } label: {
                    Text("Don't have an account? Sign Up")
                        .foregroundColor(Color.brand.textPrimary)
                }
                }
            }
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
