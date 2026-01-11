import SwiftUI
import FirebaseAuth

struct BlockDetailView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var authService: AuthService

    let block: Block

    @State private var sessions: [Session] = []
    @State private var isLoading = true

    // Session delete confirm
    @State private var showDeleteSessionConfirm = false
    @State private var pendingSessionDelete: Session? = nil

    // Block actions
    @State private var showCompleteBlockConfirm = false
    @State private var showDeleteBlockConfirm = false
    @State private var actionErrorMessage: String? = nil

    private let firestoreService = FirestoreService()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brand.surface.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Layout.listSpacing) {

                            // Status • Progress
                            VStack(alignment: .leading, spacing: Layout.contentSpacing) {
                                Text("Progress")
                                    .font(TextStyles.bodySmall)
                                    .foregroundColor(Color.brand.textSecondary)

                                BlockCardSubline(
                                    text: statusLine,
                                    style: .primary
                                )
                            }
                            .padding(.bottom, Layout.cardSpacing)
                            
                            // Notes
                            if let notes = trimmedNotes {
                                VStack(alignment: .leading, spacing: Layout.contentSpacing) {
                                    Text("Notes")
                                        .font(TextStyles.bodySmall)
                                        .foregroundColor(Color.brand.textSecondary)

                                    Text(notes)
                                        .font(TextStyles.body)
                                        .foregroundColor(Color.brand.textPrimary)
                                }
                                .padding(.bottom, Layout.cardSpacing)
                            }

                            // Sessions (full list)
                            VStack(spacing: Layout.listSpacing) {
                                ForEach(sessions) { session in
                                    SessionCard(
                                        session: session,
                                        dateStyle: .compact,
                                        onEdit: {
                                            router.openEditSession(block: block, session: session)
                                        },
                                        onDuplicate: {
                                            var dup = session
                                            dup.id = nil
                                            dup.date = Date()
                                            router.openEditSession(block: block, session: dup)
                                        },
                                        onDelete: {
                                            pendingSessionDelete = session
                                            showDeleteSessionConfirm = true
                                        }
                                    )
                                }

                                if sessions.isEmpty {
                                    Text("No sessions yet.")
                                        .font(TextStyles.bodySmall)
                                        .foregroundColor(Color.brand.textSecondary)
                                }
                            }
                        }
                        .padding(.horizontal, Layout.horizontalSpacing)
                        .padding(.top, Layout.sectionSpacing)
                        .padding(.bottom, Layout.sectionSpacing)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await loadSessions() }

            // Session delete confirm
            .alert("Delete session?", isPresented: $showDeleteSessionConfirm) {
                Button("Delete", role: .destructive) {
                    Task { await deletePendingSession() }
                }
                Button("Cancel", role: .cancel) {
                    pendingSessionDelete = nil
                }
            } message: {
                Text("This can’t be undone.")
            }

            // Block complete confirm
            .confirmationDialog(
                "Mark this block complete?",
                isPresented: $showCompleteBlockConfirm,
                titleVisibility: .visible
            ) {
                Button("Mark Complete", role: .destructive) {
                    Task { await markCompleteEarly() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This sets the block’s end date to yesterday so it appears in Completed.")
            }

            // Block delete confirm
            .confirmationDialog(
                "Delete this block?",
                isPresented: $showDeleteBlockConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Block", role: .destructive) {
                    Task { await deleteBlock() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete the block and its sessions.")
            }

            // Error alert
            .alert(
                "Something went wrong",
                isPresented: Binding(
                    get: { actionErrorMessage != nil },
                    set: { if !$0 { actionErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { actionErrorMessage = nil }
            } message: {
                Text(actionErrorMessage ?? "")
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button { router.closeSheet() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.brand.textSecondary)
            }
        }

        ToolbarItem(placement: .principal) {
            Text(block.name)
                .font(TextStyles.title)
                .foregroundColor(Color.brand.textPrimary)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    router.openEditBlock(block)
                } label: {
                    Label("Edit Block", systemImage: "pencil")
                }

                if !block.isCompleted {
                    Button {
                        showCompleteBlockConfirm = true
                    } label: {
                        Label("Mark Complete", systemImage: "checkmark.circle")
                    }
                }

                Button(role: .destructive) {
                    showDeleteBlockConfirm = true
                } label: {
                    Label("Delete Block", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.brand.textSecondary)
            }
        }
    }

    // MARK: - Derived

    private var trimmedNotes: String? {
        let t = (block.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private var statusLine: String {
        "\(block.statusText) • \(sessions.count) \(sessions.count == 1 ? "session" : "sessions")"
    }

    // MARK: - Data

    private func loadSessions() async {
        guard let userId = authService.user?.uid else {
            await MainActor.run { isLoading = false }
            return
        }
        guard let blockId = block.id else {
            await MainActor.run { isLoading = false }
            return
        }

        do {
            let fetched = try await firestoreService.fetchSessions(userId: userId, blockId: blockId)
            await MainActor.run {
                sessions = fetched // newest-first from service
                isLoading = false
            }
        } catch {
            await MainActor.run {
                sessions = []
                isLoading = false
            }
        }
    }

    private func deletePendingSession() async {
        guard let userId = authService.user?.uid else { return }
        guard let session = pendingSessionDelete else { return }
        guard let sessionId = session.id else { return }

        do {
            try await firestoreService.deleteSession(userId: userId, sessionId: sessionId)
            await MainActor.run {
                sessions.removeAll { $0.id == sessionId }
                pendingSessionDelete = nil
                NotificationCenter.default.post(name: .bellTrackDataDidChange, object: nil)
            }
        } catch {
            await MainActor.run {
                pendingSessionDelete = nil
                actionErrorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Block actions

    private func markCompleteEarly() async {
        guard let userId = authService.user?.uid else {
            await MainActor.run { actionErrorMessage = "You’re not signed in." }
            return
        }

        var updated = block

        // endDate=yesterday => isCompleted becomes true today
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        updated.endDate = yesterday

        do {
            try await firestoreService.saveBlock(userId: userId, block: updated)
            await MainActor.run {
                NotificationCenter.default.post(name: .bellTrackDataDidChange, object: nil)
                router.closeSheet()
            }
        } catch {
            await MainActor.run { actionErrorMessage = error.localizedDescription }
        }
    }

    private func deleteBlock() async {
        guard let userId = authService.user?.uid else {
            await MainActor.run { actionErrorMessage = "You’re not signed in." }
            return
        }
        guard let blockId = block.id else {
            await MainActor.run { actionErrorMessage = "Missing block id." }
            return
        }

        do {
            try await firestoreService.deleteBlock(userId: userId, blockId: blockId)
            await MainActor.run {
                NotificationCenter.default.post(name: .bellTrackDataDidChange, object: nil)
                router.closeSheet()
            }
        } catch {
            await MainActor.run { actionErrorMessage = error.localizedDescription }
        }
    }
}

