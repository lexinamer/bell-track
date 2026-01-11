import SwiftUI
import FirebaseAuth

struct HomeView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var router: AppRouter

    private let firestoreService = FirestoreService()

    @State private var blocks: [Block] = []
    @State private var sessionsByBlockId: [String: [Session]] = [:]
    @State private var isLoading: Bool = true

    // Completed section
    @State private var showCompleted: Bool = false

    // Delete session confirm
    @State private var showDeleteSessionConfirm: Bool = false
    @State private var sessionPendingDelete: (block: Block, session: Session)? = nil

    // MARK: - Derived

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
        .task { await load() }
        .refreshable { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .bellTrackDataDidChange)) { _ in
            Task { await load() }
        }
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
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {

                // Active blocks
                VStack(alignment: .leading, spacing: Layout.listSpacing) {
                    ForEach(activeBlocks) { block in
                        BlockCardActive(
                            block: block,
                            sessions: sessions(for: block.id),               // ✅ full sessions
                            statusLine: activeStatusLine(for: block),
                            onOpen: { router.openBlockDetail(block) },
                            onLogSession: { router.openLogSession(for: block) },
                            onEditSession: { session in
                                router.openEditSession(block: block, session: session)
                            },
                            onDuplicateSession: { session in
                                var dup = session
                                dup.id = nil
                                dup.date = Date()
                                router.openEditSession(block: block, session: dup)
                            },
                            onDeleteSession: { session in
                                sessionPendingDelete = (block: block, session: session)
                                showDeleteSessionConfirm = true
                            }
                        )
                    }
                }
                .padding(.horizontal, Layout.horizontalSpacing)

                // Completed blocks (collapsible)
                if !completedBlocks.isEmpty {
                    VStack(alignment: .leading, spacing: Layout.listSpacing) {

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showCompleted.toggle()
                            }
                        } label: {
                            HStack(spacing: Layout.contentSpacing) {
                                Text("Completed")
                                    .font(TextStyles.link)
                                    .foregroundColor(Color.brand.textPrimary)

                                Text("\(completedBlocks.count)")
                                    .font(TextStyles.bodySmall)
                                    .foregroundColor(Color.brand.textSecondary)

                                Spacer()

                                Image(systemName: showCompleted ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.brand.textSecondary)
                            }
                            .padding(.horizontal, Layout.horizontalSpacing)
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
                                }
                            }
                            .padding(.horizontal, Layout.horizontalSpacing)
                        }
                    }
                }

                Spacer(minLength: Layout.sectionSpacing)
            }
            .padding(.top, Layout.listSpacing)
            .padding(.bottom, Layout.sectionSpacing)
        }
    }

    // MARK: - Helpers (sessions + status lines)

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
        // Always include year at the end for completed blocks
        let startText = start.formatted(.dateTime.month(.abbreviated).day())
        let endText = end.formatted(.dateTime.month(.abbreviated).day().year())
        return "\(startText)–\(endText)"
    }

    // MARK: - Data

    private func load() async {
        guard let userId = authService.user?.uid else {
            await MainActor.run {
                blocks = []
                sessionsByBlockId = [:]
                isLoading = false
            }
            return
        }

        await MainActor.run { isLoading = true }

        do {
            let fetchedBlocks = try await firestoreService.fetchBlocks(userId: userId)
            let sortedBlocks = fetchedBlocks.sorted { $0.startDate > $1.startDate }

            var dict: [String: [Session]] = [:]
            for block in sortedBlocks {
                guard let blockId = block.id else { continue }
                let s = try await firestoreService.fetchSessions(userId: userId, blockId: blockId)
                dict[blockId] = s.sorted { $0.date > $1.date }
            }

            await MainActor.run {
                blocks = sortedBlocks
                sessionsByBlockId = dict
                isLoading = false
            }
        } catch {
            await MainActor.run {
                blocks = []
                sessionsByBlockId = [:]
                isLoading = false
            }
        }
    }

    private func confirmDeleteSession() async {
        guard let userId = authService.user?.uid else { return }
        guard let pending = sessionPendingDelete else { return }
        guard let sessionId = pending.session.id else { return }

        do {
            try await firestoreService.deleteSession(userId: userId, sessionId: sessionId)
            sessionPendingDelete = nil
            await load()
        } catch {
            // v1: fail quietly
            sessionPendingDelete = nil
        }
    }
}
