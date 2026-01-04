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
            VStack(spacing: Spacing.sm) {
                Spacer()
                    .frame(height: 60)
                
                Text("Reset Password")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color.brand.textPrimary)
                
                Text("Enter your email to receive a password reset link")
                    .font(.system(size: Typography.sm))
                    .foregroundColor(Color.brand.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
                
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
                    
                    if !message.isEmpty {
                        Text(message)
                            .font(.system(size: Typography.sm))
                            .foregroundColor(Color.brand.success)
                    }
                    
                    Button(action: sendResetEmail) {
                        if isLoading {
                            ProgressListView()
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
                    .cornerRadius(CornerRadius.md)
                    .disabled(isLoading || email.isEmpty)
                }
                .padding(.horizontal, Spacing.lg)
                
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
    
    private func sendResetEmail() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else { message = "Please enter your email"; return }
        isLoading = true
        message = ""
        
        Task {
            do {
                try await Auth.auth().sendPasswordReset(withEmail: trimmedEmail)
                await MainActor.run {
                    message = "Password reset email sent!"
                    isLoading = false
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
