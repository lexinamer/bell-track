import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authService: AuthService

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoading = false

    @State private var showSignUp = false
    @State private var showPasswordReset = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brand.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Layout.sectionSpacing) {
                        header

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
                                .textContentType(.password)
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

                            Button(action: signIn) {
                                HStack(spacing: Layout.contentSpacing) {
                                    if isLoading {
                                        ProgressView()
                                    }
                                    Text(isLoading ? "Logging in…" : "Log In")
                                        .font(TextStyles.link)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Layout.contentSpacing)
                                .foregroundColor(Color.brand.background)
                                .background(Color.brand.primary)
                                .cornerRadius(CornerRadius.md)
                            }
                            .disabled(isLoading || !canSubmit)

                            Button {
                                showPasswordReset = true
                            } label: {
                                Text("Forgot Password?")
                                    .font(TextStyles.linkSmall)
                                    .foregroundColor(Color.brand.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)

                            Button {
                                showSignUp = true
                            } label: {
                                Text("Don't have an account? Sign Up")
                                    .font(TextStyles.linkSmall)
                                    .foregroundColor(Color.brand.primary)
                            }
                            .padding(.top, Layout.contentSpacing)
                        }
                    }
                    .padding(.horizontal, Layout.horizontalSpacing)
                    .padding(.vertical, Layout.sectionSpacing)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView()
        }
        .sheet(isPresented: $showPasswordReset) {
            PasswordResetView()
        }
    }

    // MARK: - UI

    private var header: some View {
        VStack(spacing: Layout.contentSpacing) {
            HStack(spacing: Layout.contentSpacing) {
                Image("AppLogo")
                    .resizable()
                    .renderingMode(.original)
                    .frame(width: 40, height: 50)

                Text("BELL TRACK")
                    .font(TextStyles.title)
                    .foregroundColor(Color.brand.primary)
            }

            Text("Your workout journal, simplified.")
                .font(TextStyles.body)
                .foregroundColor(Color.brand.textSecondary)
        }
        .padding(.top, Layout.sectionSpacing)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(TextStyles.bodySmall)
            .foregroundColor(Color.brand.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Derived

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                try await authService.signIn(email: trimmedEmail, password: trimmedPassword)
                await MainActor.run { isLoading = false }
            } catch {
                await MainActor.run {
                    errorMessage = "Invalid email or password."
                    isLoading = false
                }
            }
        }
    }
}
