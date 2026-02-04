import SwiftUI
import FirebaseAuth
import Foundation

struct PasswordResetView: View {
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var message = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Space.md) {

                // Push content down slightly (matches LoginView)
                Spacer()
                    .frame(height: 20)

                // Title
                Text("Reset Password")
                    .font(Theme.Font.cardTitle)
                    .foregroundColor(Color.brand.textPrimary)

                Text("Enter your email to receive a password reset link.")
                    .font(Theme.Font.cardSecondary)
                    .foregroundColor(Color.brand.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Space.md)

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

                    if !message.isEmpty {
                        Text(message)
                            .font(.system(size: Theme.TypeSize.sm))
                            .foregroundColor(
                                message.contains("sent")
                                ? .green
                                : .red
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(action: sendResetEmail) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Send Reset Link")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brand.primary)
                    .foregroundColor(.white)
                    .cornerRadius(Theme.Radius.md)
                    .disabled(isLoading || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, Theme.Space.lg)

                Spacer()
            }
            .background(Color.brand.surface)
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

                    // Auto-dismiss after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        dismiss()
                    }
                }
            } catch {
                let nsError = error as NSError
                let authCode = AuthErrorCode(rawValue: nsError.code)

                let friendlyMessage: String
                switch authCode {
                case .some(.invalidEmail):
                    friendlyMessage = "Please enter a valid email address."
                case .some(.userNotFound):
                    friendlyMessage = "No account found with that email."
                case .some(.networkError):
                    friendlyMessage = "Network error. Please try again."
                default:
                    friendlyMessage = "Failed to send reset email. Please try again."
                }

                await MainActor.run {
                    message = friendlyMessage
                    isLoading = false
                }
            }
        }
    }
}
