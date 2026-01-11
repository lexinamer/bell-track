import SwiftUI
import FirebaseAuth

struct HomeView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var router: AppRouter

    // Data
    @State private var blocks: [Block] = []
    @State private var sessionsByBlockId: [String: [Session]] = [:]
    @State private var isLoading: Bool = true

    // UI state
    @State private var showCompleted: Bool = false
    @State private var showDeleteSessionConfirm: Bool = false
    @State private var sessionPendingDelete: (block: Block, session: Session)? = nil

    private let firestoreService = FirestoreService()

    // MARK: - Derived

    private var userId: String {
        authService.user?.uid ?? ""
    }

    private var activeBlocks: [Block] {
        blocks
            .filter { !$0.isCompleted }
            .sorted { $0.startDate > $1.startDate }
    }

    private var completedBlocks: [Block] {
        blocks
            .filter { $0.isCompleted }
            .sorted { $0.startDate > $1.startDate }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            if isLoading {
                ProgressView()
            } else if blocks.isEmpty {
                emptyState
            } else {
                content
            }
        }

        // Loads / refresh / data change reload
        .task { await load() }
        .refreshable { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .bellTrackDataDidChange)) { _ in
            Task { await load() }
        }

        // Confirm delete
        .confirmationDialog(
            "Delete session?",
            isPresented: $showDeleteSessionConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Session", role: .destructive) {
                Task { await confirmDeleteSession() }
            }
            Button("Cancel", role: .cancel) {
                sessionPendingDelete = nil
            }
        } message: {
            Text("This can’t be undone.")
        }
    }

    // MARK: - UI

    private var emptyState: some View {
        VStack(spacing: Layout.sectionSpacing) {
            VStack(spacing: Layout.contentSpacing) {
                Text("No blocks yet")
                    .font(TextStyles.cardTitle)
                    .foregroundColor(Color.brand.textPrimary)

                Text("Create a block to start logging sessions.")
                    .font(TextStyles.bodySmall)
                    .foregroundColor(Color.brand.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Layout.horizontalSpacing)

            Button {
                router.openCreateBlock()
            } label: {
                Text("Create a block")
                    .font(TextStyles.link)
                    .foregroundColor(Color.brand.background)
                    .padding(.horizontal, Layout.horizontalSpacing)
                    .padding(.vertical, Layout.contentSpacing)
                    .background(Color.brand.primary)
                    .cornerRadius(CornerRadius.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Layout.horizontalSpacing)
    }

    private var content: some View {
        ScrollView {
            // OUTER STACK: spacing between major page sections (Active section ↔ Completed section)
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {

                // ACTIVE BLOCKS: spacing between block cards
                VStack(alignment: .leading, spacing: Layout.listSpacing) {
                    ForEach(activeBlocks) { block in
                        BlockCardActive(
                            block: block,
                            sessions: sessions(for: block.id),
                            statusLine: activeStatusLine(for: block),
                            onOpen: { router.openBlockDetail(block) },
                            onLogSession: { router.openLogSession(for: block) },
                            onEditSession: { session in
                                router.openEditSession(block: block, session: session)
                            },
                            onDuplicateSession: { session in
                                // Duplicate should open Log Session (create) with details prefilled
                                var dup = session
                                dup.id = nil
                                dup.date = Date()
                                router.openLogSession(for: block) // open "create"
                                // NOTE: if you want prefill, pass dup via router API (needs a new router method).
                                // For now this guarantees the title/flow is "Log Session".
                            },
                            onDeleteSession: { session in
                                sessionPendingDelete = (block: block, session: session)
                                showDeleteSessionConfirm = true
                            }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: activeBlocks)
                .padding(.horizontal, Layout.horizontalSpacingNarrow)

                // COMPLETED BLOCKS (collapsible)
                if !completedBlocks.isEmpty {
                    VStack(alignment: .leading, spacing: Layout.listSpacing) {

                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showCompleted.toggle()
                            }
                        } label: {
                            HStack(spacing: Layout.contentSpacing) {
                                Text("Completed Blocks")
                                    .font(TextStyles.link)
                                    .foregroundColor(Color.brand.textPrimary)

                                Text("\(completedBlocks.count)")
                                    .font(TextStyles.bodySmall)
                                    .foregroundColor(Color.brand.textSecondary)

                                Spacer()

                                Image(systemName: "chevron.down")
                                    .rotationEffect(.degrees(showCompleted ? 180 : 0))
                                    .animation(.easeInOut(duration: 0.25), value: showCompleted)
                                    .foregroundColor(Color.brand.textSecondary)
                            }
                            .padding(.horizontal, Layout.horizontalSpacingNarrow)
                        }
                        .buttonStyle(.plain)

                        if showCompleted {
                            VStack(spacing: Layout.listSpacing) {
                                ForEach(completedBlocks) { block in
                                    BlockCardCompleted(
                                        block: block,
                                        statusLine: completedStatusLine(for: block),
                                        onOpen: { router.openBlockDetail(block) }
                                    )
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            .animation(.easeInOut(duration: 0.2), value: completedBlocks)
                            .padding(.horizontal, Layout.horizontalSpacingNarrow)
                        }
                    }
                }

                Spacer(minLength: Layout.sectionSpacing)
            }
            .padding(.top, Layout.listSpacing)
            .padding(.bottom, Layout.sectionSpacing)
        }
    }

    // MARK: - Helpers

    private func sessions(for blockId: String?) -> [Session] {
        guard let id = blockId else { return [] }
        return sessionsByBlockId[id] ?? []
    }

    private func activeStatusLine(for block: Block) -> String {
        let count = sessions(for: block.id).count
        let progress = count == 1 ? "1 session" : "\(count) sessions"

        let status: String
        if let end = block.endDate {
            status = weekProgressText(start: block.startDate, end: end)
        } else {
            status = "Ongoing"
        }

        return "\(status) • \(progress)"
    }

    private func completedStatusLine(for block: Block) -> String {
        let count = sessions(for: block.id).count
        let progress = count == 1 ? "1 session" : "\(count) sessions"

        if let end = block.endDate {
            return "\(dateRangeText(start: block.startDate, end: end)) • \(progress)"
        }

        return "Complete • \(progress)"
    }

    private func weekProgressText(start: Date, end: Date) -> String {
        let cal = Calendar.current
        let startDay = cal.startOfDay(for: start)
        let endDay = cal.startOfDay(for: end)
        let today = cal.startOfDay(for: Date())

        let totalDays = max(1, (cal.dateComponents([.day], from: startDay, to: endDay).day ?? 0) + 1)
        let totalWeeks = max(1, Int(ceil(Double(totalDays) / 7.0)))

        let elapsedDays = max(0, (cal.dateComponents([.day], from: startDay, to: today).day ?? 0))
        let currentWeek = min(totalWeeks, (elapsedDays / 7) + 1)

        return "Week \(currentWeek) of \(totalWeeks)"
    }

    private func dateRangeText(start: Date, end: Date) -> String {
        let startText = start.formatted(.dateTime.month(.abbreviated).day())
        let endText = end.formatted(.dateTime.month(.abbreviated).day().year())
        return "\(startText)–\(endText)"
    }

    // MARK: - Data

    private func load() async {
        let shouldShowBlockingLoader = blocks.isEmpty
        if shouldShowBlockingLoader {
            await MainActor.run { isLoading = true }
        }

        guard let userId = authService.user?.uid else {
            await MainActor.run { isLoading = false }
            return
        }

        do {
            let fetchedBlocks = try await firestoreService.fetchBlocks(userId: userId)

            var sessionsMap: [String: [Session]] = [:]

            for block in fetchedBlocks {
                if let blockId = block.id {
                    let sessions = try await firestoreService.fetchSessions(
                        userId: userId,
                        blockId: blockId
                    )
                    sessionsMap[blockId] = sessions
                }
            }

            await MainActor.run {
                blocks = fetchedBlocks
                sessionsByBlockId = sessionsMap
                isLoading = false
            }

        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    private func confirmDeleteSession() async {
        guard let userId = authService.user?.uid else { return }
        guard let pending = sessionPendingDelete else { return }
        guard let sessionId = pending.session.id else { return }

        do {
            try await firestoreService.deleteSession(userId: userId, sessionId: sessionId)
            await MainActor.run {
                sessionPendingDelete = nil
                // Optimistic local remove (prevents spinner + makes UI feel instant)
                if let blockId = pending.block.id {
                    sessionsByBlockId[blockId]?.removeAll { $0.id == sessionId }
                }
            }
            await load()
        } catch {
            await MainActor.run { sessionPendingDelete = nil }
        }
    }
}
