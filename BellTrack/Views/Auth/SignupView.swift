import SwiftUI
import FirebaseAuth
import Foundation

struct SignupView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Space.md) {

                // Push content down (matches Login + Reset)
                Spacer()
                    .frame(height: 20)

                // Title
                Text("Create Account")
                    .font(Theme.Font.pageTitle)
                    .foregroundColor(Color.brand.textPrimary)

                Spacer()
                    .frame(height: 20)

                // FORM
                VStack(spacing: Theme.Space.md) {

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

                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color.brand.surface)
                        .cornerRadius(Theme.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .stroke(Color.brand.border, lineWidth: 1)
                        )

                    SecureField("Confirm Password", text: $confirmPassword)
                        .padding()
                        .background(Color.brand.surface)
                        .cornerRadius(Theme.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .stroke(Color.brand.border, lineWidth: 1)
                        )

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: Theme.TypeSize.sm))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(action: signUp) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Sign Up")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brand.primary)
                    .foregroundColor(.white)
                    .cornerRadius(Theme.Radius.md)
                    .disabled(isLoading)
                }
                .padding(.horizontal, Theme.Space.lg)

                Spacer()
            }
            .background(Color.brand.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(Color.brand.textPrimary)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func signUp() {
        errorMessage = ""

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedConfirm = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty else {
            errorMessage = "Please enter an email."
            return
        }

        guard !trimmedPassword.isEmpty else {
            errorMessage = "Please enter a password."
            return
        }

        guard trimmedPassword == trimmedConfirm else {
            errorMessage = "Passwords don’t match."
            return
        }

        guard trimmedPassword.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }

        isLoading = true

        Task {
            do {
                try await authService.signUp(email: trimmedEmail, password: trimmedPassword)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                let nsError = error as NSError
                let authCode = AuthErrorCode(rawValue: nsError.code)

                let message: String
                switch authCode {
                case .some(.invalidEmail):
                    message = "That email address looks invalid."
                case .some(.emailAlreadyInUse):
                    message = "An account with this email already exists."
                case .some(.weakPassword):
                    message = "Password must be at least 6 characters."
                default:
                    message = "Failed to create account. Please try again."
                }

                await MainActor.run {
                    errorMessage = message
                    isLoading = false
                }
            }
        }
    }
}
