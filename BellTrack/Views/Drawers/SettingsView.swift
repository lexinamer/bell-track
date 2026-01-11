import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var showingChangeEmailSheet = false
    @State private var newEmail: String = ""
    @State private var showingResetPasswordConfirm = false
    @State private var showingDeleteAccountConfirm = false

    @State private var statusMessage: String?
    @State private var showingStatusAlert = false

    var body: some View {
        NavigationStack {
            List {

                // ACCOUNT SECTION
                Section {
                    Button {
                        showingChangeEmailSheet = true
                    } label: {
                        SettingsRowLabel(title: "Change Email")
                    }

                    Button {
                        showingResetPasswordConfirm = true
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
                }

                // DESTRUCTIVE SECTION
                Section {
                    Button(role: .destructive) {
                        showingDeleteAccountConfirm = true
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.brand.textSecondary)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .sheet(isPresented: $showingChangeEmailSheet) {
                changeEmailSheet
            }
            .alert("Reset Password", isPresented: $showingResetPasswordConfirm) {
                Button("Send Reset Email", role: .destructive) {
                    sendPasswordReset()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("We'll email a password reset link to your account email.")
            }
            .alert("Delete Account", isPresented: $showingDeleteAccountConfirm) {
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete your account. You may need to log in again just before deleting if Firebase asks you to re‑authenticate.")
            }
            .alert("Done", isPresented: $showingStatusAlert, actions: {
                Button("OK", role: .cancel) { }
            }, message: {
                Text(statusMessage ?? "")
            })
        }
    }

    private var changeEmailSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("New Email")) {
                    TextField("name@example.com", text: $newEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Change Email")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingChangeEmailSheet = false
                        newEmail = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        changeEmail()
                    }
                    .disabled(newEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func changeEmail() {
        let trimmed = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let user = Auth.auth().currentUser else {
            statusMessage = "You need to be logged in to change your email."
            showingStatusAlert = true
            return
        }

        user.sendEmailVerification(beforeUpdatingEmail: trimmed) { error in
            if let error = error {
                statusMessage = "Couldn't start email update: \(error.localizedDescription)"
            } else {
                statusMessage = "We've sent a verification email to \(trimmed). Click the link in that email to confirm your new address."
                newEmail = ""
                showingChangeEmailSheet = false
            }
            showingStatusAlert = true
        }
    }

    private func deleteAccount() {
        guard let user = Auth.auth().currentUser else {
            statusMessage = "You need to be logged in to delete your account."
            showingStatusAlert = true
            return
        }
        let uid = user.uid

        deleteUserData(for: uid) { dataError in
            if let dataError = dataError {
                self.statusMessage = "Couldn't delete your data: \(dataError.localizedDescription)"
                self.showingStatusAlert = true
                return
            }

            user.delete { error in
                if let error = error {
                    self.statusMessage = "Couldn't delete account: \(error.localizedDescription)\nTry logging out and back in, then deleting again."
                    self.showingStatusAlert = true
                } else {
                    self.statusMessage = "Your account and workout history have been deleted."
                    self.showingStatusAlert = true
                    do {
                        try self.authService.signOut()
                    } catch {
                        print("Error signing out after delete: \(error)")
                    }
                }
            }
        }
    }

    private func deleteUserData(for uid: String, completion: @escaping (Error?) -> Void) {
        let db = Firestore.firestore()
        let collections = ["blocks", "date_notes"]
        var remaining = collections.count
        var firstError: Error?

        func checkComplete() {
            remaining -= 1
            if remaining == 0 {
                completion(firstError)
            }
        }

        for collection in collections {
            db.collection(collection).whereField("userId", isEqualTo: uid).getDocuments { snapshot, error in
                if let error = error {
                    if firstError == nil {
                        firstError = error
                    }
                    checkComplete()
                    return
                }

                guard let documents = snapshot?.documents else {
                    checkComplete()
                    return
                }

                let batch = db.batch()
                for doc in documents {
                    batch.deleteDocument(doc.reference)
                }

                batch.commit { batchError in
                    if let batchError = batchError {
                        if firstError == nil {
                            firstError = batchError
                        }
                    }
                    checkComplete()
                }
            }
        }
    }

    private func sendPasswordReset() {
        guard let email = Auth.auth().currentUser?.email else {
            statusMessage = "We couldn't find an email for your account."
            showingStatusAlert = true
            return
        }

        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                statusMessage = "Couldn't send reset email: \(error.localizedDescription)"
            } else {
                statusMessage = "Password reset email sent to \(email)."
            }
            showingStatusAlert = true
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
