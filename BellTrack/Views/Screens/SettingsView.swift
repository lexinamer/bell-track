import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UIKit

struct SettingsView: View {

    // MARK: - Environment
    @EnvironmentObject private var authService: AuthService
    @Environment(\.openURL) private var openURL

    // MARK: - State
    @State private var showingDeleteConfirm1 = false
    @State private var showingDeleteConfirm2 = false
    @State private var deleteConfirmText = ""
    @State private var isDeletingAccount = false

    @State private var showingReauthAlert = false
    @State private var deleteErrorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            LargeTitleHeader(title: "Settings")

            List {

                // MARK: - App
                Section("App") {

                NavigationLink {
                    ExercisesView()
                } label: {
                    settingsRow(
                        title: "Exercises",
                        systemImage: "dumbbell"
                    )
                }

            }

            // MARK: - Feedback
            Section("Feedback") {

                Button {
                    sendFeedbackEmail()
                } label: {
                    settingsRow(
                        title: "Send feedback",
                        systemImage: "envelope"
                    )
                }
                .buttonStyle(.plain)

            }

            // MARK: - Account
            Section("Account") {

                Button {
                    signOut()
                } label: {
                    settingsRow(
                        title: "Log out",
                        systemImage: "arrow.right.square"
                    )
                }
                .buttonStyle(.plain)
                .disabled(isDeletingAccount)

                Button {
                    showingDeleteConfirm1 = true
                } label: {
                    settingsRow(
                        title: "Delete account",
                        systemImage: "trash",
                        isDestructive: true
                    )
                }
                .buttonStyle(.plain)
                .disabled(isDeletingAccount)

            }

            // MARK: - Version
            Section {

                Text(appVersionText)
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(Color.brand.textSecondary)
                    .padding(.vertical, Theme.Space.sm)

            }

            }
            .scrollContentBackground(.hidden)
            .background(Color.brand.background)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // Empty spacer to maintain consistent layout with other tabs
                Color.clear.frame(width: 44, height: 44)
            }
        }

        // MARK: - Delete Flow

        .alert("Delete account?", isPresented: $showingDeleteConfirm1) {

            Button("Continue", role: .destructive) {
                deleteConfirmText = ""
                showingDeleteConfirm2 = true
            }

            Button("Cancel", role: .cancel) {}

        } message: {
            Text("This will permanently delete your account and all workout data.")
        }

        .alert("Confirm deletion", isPresented: $showingDeleteConfirm2) {

            TextField("Type DELETE", text: $deleteConfirmText)

            Button("Delete", role: .destructive) {
                Task { await deleteAccount() }
            }
            .disabled(
                deleteConfirmText
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased() != "DELETE"
                || isDeletingAccount
            )

            Button("Cancel", role: .cancel) {}

        } message: {
            Text("Type DELETE to confirm.")
        }

        .alert("Can't delete right now", isPresented: $showingReauthAlert) {

            Button("Log out", role: .destructive) {
                signOut()
            }

            Button("OK", role: .cancel) {}

        } message: {
            Text(deleteErrorMessage ?? "Please log out and log back in, then try again.")
        }
    }


    // MARK: - Row

    private func settingsRow(
        title: String,
        systemImage: String,
        isDestructive: Bool = false
    ) -> some View {

        HStack {

            Image(systemName: systemImage)
                .foregroundColor(isDestructive ? Color.brand.destructive : Color.brand.textPrimary)

            Text(title)
                .font(Theme.Font.cardSecondary)
                .foregroundColor(isDestructive ? Color.brand.destructive : Color.brand.textPrimary)

            Spacer()
        }
        .contentShape(Rectangle())
    }


    // MARK: - Actions

    @MainActor
    private func signOut() {
        try? Auth.auth().signOut()
    }


    @MainActor
    private func deleteAccount() async {

        isDeletingAccount = true
        defer { isDeletingAccount = false }

        guard let user = Auth.auth().currentUser else {
            deleteErrorMessage = "Please log out and log back in."
            showingReauthAlert = true
            return
        }

        let uid = user.uid
        let db = Firestore.firestore()

        do {

            try await deleteUserData(db: db, uid: uid)
            try await user.delete()
            try? Auth.auth().signOut()

        } catch {

            let nsError = error as NSError

            if AuthErrorCode(rawValue: nsError.code) == .requiresRecentLogin {
                deleteErrorMessage = "Please log out and log back in, then try again."
            } else {
                deleteErrorMessage = error.localizedDescription
            }

            showingReauthAlert = true
        }
    }


    private func deleteUserData(db: Firestore, uid: String) async throws {

        let userDoc = db.collection("users").document(uid)
        let batch = db.batch()

        for collection in ["exercises", "blocks", "workoutTemplates", "workouts"] {

            let snap = try await userDoc.collection(collection).getDocuments()

            snap.documents.forEach {
                batch.deleteDocument($0.reference)
            }
        }

        batch.deleteDocument(userDoc)

        try await batch.commit()
    }


    // MARK: - Feedback

    private func sendFeedbackEmail() {

        var components = URLComponents()

        components.scheme = "mailto"
        components.path = "lexinamer@gmail.com"

        components.queryItems = [

            .init(name: "subject", value: "Bell Track Feedback"),

            .init(
                name: "body",
                value: "\n\n—\nDevice: \(UIDevice.current.model)\niOS: \(UIDevice.current.systemVersion)"
            )
        ]

        if let url = components.url {
            openURL(url)
        }
    }


    // MARK: - Version

    private var appVersionText: String {

        let version =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"

        return "Version \(version)"
    }
}
