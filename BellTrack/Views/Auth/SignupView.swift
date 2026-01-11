import SwiftUI
import FirebaseAuth

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    @State private var errorMessage = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brand.background.ignoresSafeArea()

                VStack(spacing: Layout.sectionSpacing) {
                    Text("Create Account")
                        .font(TextStyles.title)
                        .foregroundColor(Color.brand.textPrimary)

                    VStack(spacing: Layout.contentSpacing) {
                        fieldLabel("Email")
                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textContentType(.username)
                            .padding(.horizontal, Layout.horizontalSpacingNarrow)
                            .padding(.vertical, Layout.contentSpacing)
                            .background(Color.brand.surface)
                            .cornerRadius(CornerRadius.md)

                        fieldLabel("Password")
                        SecureField("Password", text: $password)
                            .textContentType(.newPassword)
                            .padding(.horizontal, Layout.horizontalSpacingNarrow)
                            .padding(.vertical, Layout.contentSpacing)
                            .background(Color.brand.surface)
                            .cornerRadius(CornerRadius.md)

                        fieldLabel("Confirm Password")
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .padding(.horizontal, Layout.horizontalSpacingNarrow)
                            .padding(.vertical, Layout.contentSpacing)
                            .background(Color.brand.surface)
                            .cornerRadius(CornerRadius.md)

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(TextStyles.bodySmall)
                                .foregroundColor(Color.brand.destructive)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: signUp) {
                            HStack(spacing: Layout.contentSpacing) {
                                if isLoading { ProgressView() }
                                Text(isLoading ? "Creating…" : "Sign Up")
                                    .font(TextStyles.link)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Layout.contentSpacing)
                            .foregroundColor(Color.brand.background)
                            .background(Color.brand.primary)
                            .cornerRadius(CornerRadius.md)
                        }
                        .disabled(isLoading || !canSubmit)
                    }

                    Spacer()
                }
                .padding(.horizontal, Layout.horizontalSpacing)
                .padding(.vertical, Layout.sectionSpacing)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(Color.brand.textPrimary)
                    }
                }
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(TextStyles.bodySmall)
            .foregroundColor(Color.brand.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        password.count >= 6 &&
        password == confirmPassword
    }

    private func signUp() {
        errorMessage = ""

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedConfirm = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty else { errorMessage = "Please enter an email."; return }
        guard !trimmedPassword.isEmpty else { errorMessage = "Please enter a password."; return }
        guard trimmedPassword.count >= 6 else { errorMessage = "Password must be at least 6 characters."; return }
        guard trimmedPassword == trimmedConfirm else { errorMessage = "Passwords don't match."; return }

        isLoading = true

        Task {
            do {
                try await authService.signUp(email: trimmedEmail, password: trimmedPassword)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = friendlySignUpError(error)
                    isLoading = false
                }
            }
        }
    }

    private func friendlySignUpError(_ error: Error) -> String {
        let nsError = error as NSError
        if let authError = AuthErrorCode(_bridgedNSError: nsError) {
            switch authError.code {
            case .invalidEmail:
                return "That email address looks invalid."
            case .emailAlreadyInUse:
                return "An account with this email already exists."
            case .weakPassword:
                return "Password must be at least 6 characters."
            default:
                return "Failed to create account. Please try again."
            }
        }
        return "Failed to create account. Please try again."
    }
}
