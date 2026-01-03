import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        NavigationStack {
            List {

                // ACCOUNT SECTION
                Section {
                    Button {
                        // TODO: hook up change email flow
                    } label: {
                        SettingsRowLabel(title: "Change Email")
                    }

                    Button {
                        // TODO: hook up reset password flow
                    } label: {
                        SettingsRowLabel(title: "Reset Password")
                    }

                    Button {
                        handleLogout()
                    } label: {
                        SettingsRowLabel(title: "Log Out")
                    }

                } header: {
                    Text("Account")
                        .font(TextStyles.subtextStrong)
                        .foregroundColor(Color.brand.textSecondary)
                        .textCase(nil)   // ← prevents auto-uppercase
                        .padding(.leading, 4)
                }

                // DESTRUCTIVE SECTION
                Section {
                    Button(role: .destructive) {
                        // TODO: delete account flow
                    } label: {
                        SettingsRowLabel(
                            title: "Delete Account",
                            isDestructive: true
                        )
                    }

                } header: {
                    Text(" ")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.brand.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.brand.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func handleLogout() {
        do {
            try authService.signOut()
            // Your auth gate should flip back to LoginView when user becomes nil.
        } catch {
            print("Error signing out: \(error)")
        }
    }
}

// MARK: - Row Label

private struct SettingsRowLabel: View {
    let title: String
    var isDestructive: Bool = false

    var body: some View {
        HStack {
            Text(title)
                .font(TextStyles.body)
                .foregroundColor(
                    isDestructive ? Color.brand.destructive : Color.brand.textPrimary
                )

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.brand.textSecondary.opacity(0.7))
        }
        .contentShape(Rectangle())
    }
}
