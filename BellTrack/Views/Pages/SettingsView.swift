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
    @State private var exercises: [ExerciseDefinition] = []
    @State private var newExercise = ""
    @State private var isLoading = true
    @State private var editingExerciseId: UUID? = nil
    @State private var editingName = ""

    @State private var showingDeleteConfirm1 = false
    @State private var showingDeleteConfirm2 = false
    @State private var deleteConfirmText: String = ""
    @State private var isDeletingAccount = false
    @State private var showingReauthAlert = false
    @State private var deleteErrorMessage: String? = nil
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastType: ToastType = .error

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brand.background.ignoresSafeArea()

                List {

                    // MARK: - Add Exercise
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

                    // MARK: - Exercises List
                    Section {
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            ForEach($exercises) { $exercise in
                                SettingsExerciseRow(
                                    exercise: $exercise,
                                    isEditing: editingExerciseId == exercise.id,
                                    editingName: $editingName,
                                    onTap: {
                                        startEditing(exercise)
                                    },
                                    onCommit: {
                                        commitEdit(for: exercise.id)
                                    },
                                    onToggleHidden: {
                                        exercise.isHidden.toggle()
                                        Task { await saveSettings() }
                                    }
                                )
                            }
                            .onMove { from, to in
                                exercises.move(fromOffsets: from, toOffset: to)
                                Task { await saveSettings() }
                            }
                            .onDelete { indexSet in
                                exercises.remove(atOffsets: indexSet)
                                Task { await saveSettings() }
                            }
                        }
                    } header: {
                        HStack {
                            Text("Exercises")
                            Spacer()
                            EditButton()
                                .font(Theme.Font.meta)
                                .foregroundColor(Color.brand.primary)
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
        .toast(isShowing: $showToast, message: toastMessage, type: toastType)
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

        // Check for duplicate (case-insensitive)
        let isDuplicate = exercises.contains { $0.name.lowercased() == trimmed.lowercased() }
        if isDuplicate {
            toastMessage = "Exercise already exists"
            toastType = .error
            showToast = true
            return
        }

        exercises.append(ExerciseDefinition(name: trimmed))
        newExercise = ""
        Task { await saveSettings() }
    }

    private func startEditing(_ exercise: ExerciseDefinition) {
        editingExerciseId = exercise.id
        editingName = exercise.name
    }

    private func commitEdit(for id: UUID) {
        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            editingExerciseId = nil
            return
        }

        if let index = exercises.firstIndex(where: { $0.id == id }) {
            exercises[index].name = trimmed
            Task { await saveSettings() }
        }
        editingExerciseId = nil
    }

    private func loadSettings() async {
        guard let userId = authService.user?.uid else { return }
        isLoading = true
        do {
            let settings = try await firestoreService.fetchSettings(userId: userId)
            exercises = settings.exercises
        } catch {
            toastMessage = "Failed to load settings"
            toastType = .error
            showToast = true
        }
        isLoading = false
    }

    private func saveSettings() async {
        guard let userId = authService.user?.uid else { return }
        let settings = Settings(id: "main", userId: userId, exercises: exercises)
        do {
            try await firestoreService.saveSettings(settings)
        } catch {
            toastMessage = "Failed to save settings"
            toastType = .error
            showToast = true
        }
    }

    // MARK: - Account Actions

    @MainActor
    private func signOut() {
        do {
            try Auth.auth().signOut()
            dismiss()
        } catch {
            toastMessage = "Failed to sign out"
            toastType = .error
            showToast = true
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
        let workoutsRef = db.collection("users/\(uid)/workouts")
        let settingsRef = db.collection("users/\(uid)/settings")

        let workoutSnapshot = try await workoutsRef.getDocuments()

        let batch = db.batch()

        for doc in workoutSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }

        batch.deleteDocument(settingsRef.document("main"))

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

// MARK: - Settings Exercise Row Component

struct SettingsExerciseRow: View {
    @Binding var exercise: ExerciseDefinition
    let isEditing: Bool
    @Binding var editingName: String
    let onTap: () -> Void
    let onCommit: () -> Void
    let onToggleHidden: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            if isEditing {
                TextField("Exercise name", text: $editingName)
                    .font(Theme.Font.body)
                    .foregroundColor(Color.brand.textPrimary)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        onCommit()
                    }
                    .onAppear {
                        isFocused = true
                    }
            } else {
                Text(exercise.name)
                    .font(Theme.Font.body)
                    .foregroundColor(exercise.isHidden ? Color.brand.textSecondary : Color.brand.textPrimary)
                    .strikethrough(exercise.isHidden)
                    .onTapGesture {
                        onTap()
                    }
            }

            Spacer()

            Button {
                onToggleHidden()
            } label: {
                Image(systemName: exercise.isHidden ? "eye.slash" : "eye")
                    .font(.system(size: 16))
                    .foregroundColor(exercise.isHidden ? Color.brand.textSecondary : Color.brand.primary)
            }
            .buttonStyle(.plain)
        }
    }
}
