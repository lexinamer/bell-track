import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SettingsView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var feedbackText: String = ""

    @State private var showingDeleteConfirm = false
    @State private var showingFinalDeleteConfirm = false

    @State private var statusMessage: String? = nil
    @State private var showingStatusAlert = false
    @State private var isSendingFeedback = false
    @State private var isDeletingAccount = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brand.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {

                        // FEEDBACK
                        sectionHeader("Feedback")
                        card {
                            VStack(alignment: .leading, spacing: 12) {
                                TextEditor(text: $feedbackText)
                                    .font(TextStyles.body)
                                    .foregroundColor(Color.brand.textPrimary)
                                    .frame(minHeight: 120)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                                    .overlay(alignment: .topLeading) {
                                        if feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            Text("Tell me what’s working, what’s annoying, what you want next…")
                                                .font(TextStyles.body)
                                                .foregroundColor(Color.brand.textSecondary)
                                                .padding(.top, 10)
                                                .padding(.horizontal, 6)
                                        }
                                    }

                                Divider()

                                Button {
                                    Task { await sendFeedback() }
                                } label: {
                                    HStack(spacing: 10) {
                                        if isSendingFeedback {
                                            ProgressView()
                                        }
                                        Text(isSendingFeedback ? "Sending…" : "Send Feedback")
                                            .font(TextStyles.link)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                }
                                .buttonStyle(.plain)
                                .disabled(isSendingFeedback || feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .foregroundColor(
                                    (isSendingFeedback || feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    ? Color.brand.textSecondary
                                    : Color.brand.primary
                                )
                            }
                        }
                        
                        Spacer()

                        // ACCOUNT
                        sectionHeader("Account")
                        card {
                            VStack(spacing: 0) {

                                settingsRow(
                                    title: "Log out",
                                    systemImage: "rectangle.portrait.and.arrow.right",
                                    titleColor: Color.brand.textPrimary,
                                    trailing: AnyView(
                                        Image(systemName: "arrow.right.square")
                                            .foregroundColor(Color.brand.textSecondary.opacity(0.8))
                                    )
                                ) {
                                    handleLogout()
                                }

                                Divider()

                                settingsRow(
                                    title: "Delete account",
                                    systemImage: "trash",
                                    titleColor: Color.brand.destructive,
                                    trailing: AnyView(
                                        Image(systemName: "trash")
                                            .foregroundColor(Color.brand.destructive.opacity(0.9))
                                    )
                                ) {
                                    showingDeleteConfirm = true
                                }
                            }
                        }

                        // VERSION (simple line, no label)
                        Text(appVersionLine)
                            .font(TextStyles.bodySmall)
                            .foregroundColor(Color.brand.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 6)

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.brand.textSecondary)
                            .frame(width: 44, height: 44)
                            .background(Color.brand.surface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
            }

            // Delete confirm 1
            .confirmationDialog(
                "Delete account?",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Continue", role: .destructive) {
                    showingFinalDeleteConfirm = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete your account and workout history.")
            }

            // Delete confirm 2 (final)
            .confirmationDialog(
                "This can’t be undone.",
                isPresented: $showingFinalDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(isDeletingAccount ? "Deleting…" : "Delete Account", role: .destructive) {
                    Task { await deleteAccount() }
                }
                .disabled(isDeletingAccount)

                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You may need to log in again if Firebase asks you to re-authenticate.")
            }

            // Status alert
            .alert("Done", isPresented: $showingStatusAlert, actions: {
                Button("OK", role: .cancel) { }
            }, message: {
                Text(statusMessage ?? "")
            })
        }
    }

    // MARK: - UI helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(TextStyles.bodySmall)
            .foregroundColor(Color.brand.textSecondary)
            .padding(.leading, 6)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.brand.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 2)
    }

    private func settingsRow(
        title: String,
        systemImage: String,
        titleColor: Color,
        trailing: AnyView,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(TextStyles.body)
                    .foregroundColor(titleColor)

                Spacer()

                trailing
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var appVersionLine: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Version \(version)"
    }

    // MARK: - Actions

    private func handleLogout() {
        do {
            try authService.signOut()
            // ContentView's auth gate should take over and show LoginView.
            dismiss()
        } catch {
            statusMessage = "Couldn’t log out. Please try again."
            showingStatusAlert = true
        }
    }

    private func sendFeedback() async {
        let trimmed = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let user = Auth.auth().currentUser else {
            statusMessage = "You need to be logged in to send feedback."
            showingStatusAlert = true
            return
        }

        isSendingFeedback = true
        defer { isSendingFeedback = false }

        do {
            let db = Firestore.firestore()
            try await db.collection("feedback").addDocument(data: [
                "userId": user.uid,
                "email": user.email ?? "",
                "message": trimmed,
                "createdAt": Timestamp(date: Date())
            ])

            await MainActor.run {
                feedbackText = ""
                statusMessage = "Thanks — feedback sent."
                showingStatusAlert = true
            }
        } catch {
            await MainActor.run {
                statusMessage = "Couldn’t send feedback. Try again."
                showingStatusAlert = true
            }
        }
    }

    private func deleteAccount() async {
        guard let user = Auth.auth().currentUser else {
            statusMessage = "You need to be logged in to delete your account."
            showingStatusAlert = true
            return
        }

        isDeletingAccount = true
        defer { isDeletingAccount = false }

        let uid = user.uid

        do {
            try await deleteUserData(uid: uid)

            // Delete auth user last
            try await user.delete()

            await MainActor.run {
                statusMessage = "Your account and workout history have been deleted."
                showingStatusAlert = true
            }

            // Sign out locally (best-effort)
            do { try authService.signOut() } catch { }

        } catch {
            await MainActor.run {
                statusMessage = "Couldn’t delete account. You may need to log out and back in, then try again."
                showingStatusAlert = true
            }
        }
    }

    private func deleteUserData(uid: String) async throws {
        let db = Firestore.firestore()

        // Adjust collections here if your schema differs.
        let collections = ["blocks", "sessions", "feedback"]

        for collection in collections {
            let snap = try await db.collection(collection)
                .whereField("userId", isEqualTo: uid)
                .getDocuments()

            if snap.documents.isEmpty { continue }

            let batch = db.batch()
            snap.documents.forEach { batch.deleteDocument($0.reference) }
            try await batch.commit()
        }
    }
}
