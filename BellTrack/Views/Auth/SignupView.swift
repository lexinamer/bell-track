import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.sm) {
                Spacer()
                    .frame(height: 60)
                
                Text("Create Account")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color.brand.textPrimary)
                
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
                    
                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color.brand.surface)
                        .cornerRadius(CornerRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .stroke(Color.brand.border, lineWidth: 1)
                        )
                    
                    SecureField("Confirm Password", text: $confirmPassword)
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
                    .cornerRadius(CornerRadius.md)
                    .disabled(isLoading)
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
    
    private func signUp() {
        errorMessage = ""
        
        guard password == confirmPassword else {
            errorMessage = "Passwords don't match"
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await authService.signUp(email: email, password: password)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create account"
                    isLoading = false
                }
            }
        }
    }
}
