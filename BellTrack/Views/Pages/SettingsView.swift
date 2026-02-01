import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SettingsView: View {

    // MARK: - Environment
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    // MARK: - State
    @State private var firestoreService = FirestoreService()
    @State private var exercises: [String] = []
    @State private var newExercise = ""
    @State private var isLoading = true
    
    @State private var showingDeleteConfirm1 = false
    @State private var showingDeleteConfirm2 = false
    @State private var deleteConfirmText: String = ""
    @State private var isDeletingAccount = false
    @State private var showingReauthAlert = false
    @State private var deleteErrorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brand.background.ignoresSafeArea()

                List {
                    
                    // MARK: - Exercises
                    Section {
                        HStack {
                            TextField("Add exercise", text: $newExercise)
                                .font(Theme.Font.body)
                                .foregroundColor(Color.brand.textPrimary)
                                .submitLabel(.done)
                                .onSubmit {
                                    addExercise()
                                }
                            
                            Button {
                                addExercise()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(newExercise.isEmpty ? Color.brand.textSecondary : Color.brand.primary)
                            }
                            .disabled(newExercise.isEmpty)
                        }
                    }
                    
                    Section("Exercises") {
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            ForEach(exercises, id: \.self) { exercise in
                                Text(exercise)
                                    .font(Theme.Font.body)
                                    .foregroundColor(Color.brand.textPrimary)
                            }
                            .onDelete { indexSet in
                                exercises.remove(atOffsets: indexSet)
                                Task { await saveSettings() }
                            }
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
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color.brand.textPrimary)
                        }
                        .buttonStyle(.plain)
                    }

                    ToolbarItem(placement: .principal) {
                        Text("Settings")
                            .font(Theme.Font.title)
                            .foregroundColor(Color.brand.textPrimary)
                    }
                }
                .toolbarBackground(Color.brand.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
            }
        }
        .task {
            await loadSettings()
        }
        // MARK: - Delete flow
        .alert("Delete account?", isPresented: $showingDeleteConfirm1) {
            Button("Continue", role: .destructive) {
                deleteConfirmText = ""
                showingDeleteConfirm2 = true
            }
            Button("Cancel", role: .cancel) { }
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
                    .uppercased() != "DELETE" || isDeletingAccount
            )
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Type DELETE to confirm.")
        }
        .alert("Can't delete right now", isPresented: $showingReauthAlert) {
            Button("Log out", role: .destructive) {
                signOut()
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteErrorMessage ?? "Please log out and log back in, then try again.")
        }
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
    
    // MARK: - Exercise Actions
    
    private func addExercise() {
        let trimmed = newExercise.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        exercises.append(trimmed)
        newExercise = ""
        Task { await saveSettings() }
    }
    
    private func loadSettings() async {
        guard let userId = authService.user?.uid else { return }
        isLoading = true
        do {
            let settings = try await firestoreService.fetchSettings(userId: userId)
            exercises = settings.exercises
        } catch {
            print("Error loading settings: \(error)")
        }
        isLoading = false
    }
    
    private func saveSettings() async {
        guard let userId = authService.user?.uid else { return }
        let settings = Settings(id: userId, userId: userId, exercises: exercises)
        do {
            try await firestoreService.saveSettings(settings)
        } catch {
            print("Error saving settings: \(error)")
        }
    }

    // MARK: - Account Actions

    @MainActor
    private func signOut() {
        do {
            try Auth.auth().signOut()
            dismiss()
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
            dismiss()

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
        let workoutsRef = db.collection("workouts")
        let settingsRef = db.collection("settings")

        let workoutSnapshot = try await workoutsRef
            .whereField("userId", isEqualTo: uid)
            .getDocuments()

        let batch = db.batch()

        for doc in workoutSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        
        batch.deleteDocument(settingsRef.document(uid))

        try await batch.commit()
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
