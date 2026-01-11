import SwiftUI
import FirebaseAuth

struct PasswordResetView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var message = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brand.background.ignoresSafeArea()

                VStack(spacing: Layout.sectionSpacing) {
                    VStack(spacing: Layout.contentSpacing) {
                        Text("Reset Password")
                            .font(TextStyles.title)
                            .foregroundColor(Color.brand.textPrimary)

                        Text("Enter your email to receive a password reset link.")
                            .font(TextStyles.bodySmall)
                            .foregroundColor(Color.brand.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: Layout.contentSpacing) {
                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .padding(.horizontal, Layout.horizontalSpacingNarrow)
                            .padding(.vertical, Layout.contentSpacing)
                            .background(Color.brand.surface)
                            .cornerRadius(CornerRadius.md)

                        if !message.isEmpty {
                            Text(message)
                                .font(TextStyles.bodySmall)
                                .foregroundColor(Color.brand.success)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: sendResetEmail) {
                            HStack(spacing: Layout.contentSpacing) {
                                if isLoading { ProgressView() }
                                Text(isLoading ? "Sending…" : "Send Reset Link")
                                    .font(TextStyles.link)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Layout.contentSpacing)
                            .foregroundColor(Color.brand.background)
                            .background(Color.brand.primary)
                            .cornerRadius(CornerRadius.md)
                        }
                        .disabled(isLoading || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    private func sendResetEmail() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            message = "Please enter your email."
            return
        }

        isLoading = true
        message = ""

        Task {
            do {
                try await Auth.auth().sendPasswordReset(withEmail: trimmedEmail)
                await MainActor.run {
                    message = "Password reset email sent!"
                    isLoading = false
                }
                // Dismiss after a short beat
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    message = friendlyResetError(error)
                    isLoading = false
                }
            }
        }
    }

    private func friendlyResetError(_ error: Error) -> String {
        let nsError = error as NSError
        let code = AuthErrorCode(rawValue: nsError.code)

        switch code {
        case .some(.invalidEmail):
            return "Please enter a valid email address."
        case .some(.userNotFound):
            return "No account found with that email."
        case .some(.networkError):
            return "Network error. Please try again."
        default:
            return "Failed to send reset email. Please try again."
        }
    }
}
