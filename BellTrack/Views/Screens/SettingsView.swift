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
    @State private var deleteConfirmText: String = ""
    @State private var isDeletingAccount = false

    @State private var showingReauthAlert = false
    @State private var deleteErrorMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {

            // HEADER
            HStack {
                Text("Settings")
                    .font(Theme.Font.title)
                    .foregroundColor(.brand.textPrimary)

                Spacer()
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, Theme.Space.sm)
            .background(Color.brand.background)

            Divider()
                .foregroundColor(Color.brand.border)

            // CONTENT
            ZStack {
                Color.brand.background.ignoresSafeArea()

                List {

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

                    // MARK: - About
                    Section {
                        VStack(alignment: .leading, spacing: Theme.Space.sm) {
                            Text(appVersionText)
                                .font(Theme.Font.meta)
                                .foregroundColor(Color.brand.textSecondary)

                            Text("Workout tracking built for simplicity.")
                                .font(Theme.Font.meta)
                                .foregroundColor(Color.brand.textSecondary)
                        }
                        .padding(.vertical, Theme.Space.sm)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        // alerts stay exactly as you already have them
    }

    // MARK: - Row helper

    private func settingsRow(
        title: String,
        systemImage: String,
        isDestructive: Bool = false
    ) -> some View {
        HStack {
            Text(title)
                .font(Theme.Font.body)
                .foregroundColor(
                    isDestructive ? .red : Color.brand.textPrimary
                )

            Spacer()

            Image(systemName: systemImage)
                .font(.system(size: Theme.TypeSize.sm))
                .foregroundColor(
                    isDestructive ? .red : Color.brand.textSecondary
                )
        }
    }

    // MARK: - Actions

    @MainActor
    private func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("Error signing out:", error)
        }
    }

    @MainActor
    private func deleteAccount() async {
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        guard let user = Auth.auth().currentUser else {
            deleteErrorMessage = "Please log out and log back in, then try again."
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
                deleteErrorMessage = "For security, please log out and log back in, then try deleting again."
            } else {
                deleteErrorMessage = error.localizedDescription
            }
            showingReauthAlert = true
        }
    }

    private func deleteUserData(db: Firestore, uid: String) async throws {

        let userRef = db.collection("users").document(uid)

        // 1. Delete workouts
        let workoutsSnapshot = try await userRef
            .collection("workouts")
            .getDocuments()

        let workoutBatch = db.batch()
        for doc in workoutsSnapshot.documents {
            workoutBatch.deleteDocument(doc.reference)
        }
        try await workoutBatch.commit()

        // 2. Delete blocks
        let blocksSnapshot = try await userRef
            .collection("blocks")
            .getDocuments()

        let blockBatch = db.batch()
        for doc in blocksSnapshot.documents {
            blockBatch.deleteDocument(doc.reference)
        }
        try await blockBatch.commit()

        // 3. Delete user document
        try await userRef.delete()
    }

    // MARK: - Feedback

    private func sendFeedbackEmail() {
        let subject = "Workout App Feedback"
        let body = "\n\n—\nDevice: \(UIDevice.current.model)\niOS: \(UIDevice.current.systemVersion)"

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "lexinamer@gmail.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]

        guard let url = components.url else { return }
        openURL(url)
    }

    // MARK: - Version

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        return "Version \(version)"
    }
}
