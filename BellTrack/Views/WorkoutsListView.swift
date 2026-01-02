import SwiftUI
import FirebaseAuth

// For full-screen edit routing
struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}

// For duplicate routing (in-memory copy, not yet saved)
struct DuplicateContext: Identifiable {
    let id = UUID()
    let date: Date
    let blocks: [WorkoutBlock]
    let note: DateNote?
}

// MARK: - MAIN VIEW

struct WorkoutsListView: View {
    @EnvironmentObject var authService: AuthService

    @State private var blocks: [WorkoutBlock] = []
    @State private var dateNotes: [Date: DateNote] = [:]

    @State private var isLoading = true
    @State private var showAddWorkout = false
    @State private var editingDate: Date?
    @State private var showInsights = false
    @State private var duplicateContext: DuplicateContext?   // 👈 new

    private let firestoreService = FirestoreService()
    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brand.background.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                } else if groupedBlocks.isEmpty {
                    VStack(spacing: Spacing.md) {
                        Text("No workouts yet")
                            .font(.system(size: Typography.lg))
                            .foregroundColor(Color.brand.textSecondary)

                        Text("Tap + to add your first workout")
                            .font(.system(size: Typography.sm))
                            .foregroundColor(Color.brand.textSecondary)
                    }
                } else {
                    WorkoutsList(
                        groupedBlocks: groupedBlocks,
                        dateNotes: dateNotes,
                        onEditDay: { date in editingDate = date },
                        onDuplicateDay: { date in duplicateDay(for: date) },
                        onDeleteDay: { date in deleteDay(for: date) }
                    )
                }
            }
            .toolbar {
                // LEFT: hamburger menu
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        if let email = authService.user?.email {
                            Text(email)
                        }

                        Divider()
                        
                        Button {
                            showInsights = true
                        } label: {
                            Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
                        }

                        Divider()

                        Button(role: .destructive) {
                            do {
                                try authService.signOut()
                            } catch {
                                print("Error signing out:", error)
                            }
                        } label: {
                            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: Typography.xl))
                    }
                    .tint(Color.brand.textPrimary)
                }

                // CENTER: title
                ToolbarItem(placement: .principal) {
                    Text("Workouts")
                        .font(.system(size: Typography.xl, weight: .semibold))
                        .foregroundColor(Color.brand.textPrimary)
                }

                // RIGHT: add button
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddWorkout = true } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brand.secondary)
                }
            }
            .navigationBarTitleDisplayMode(.inline)

            // ADD NEW WORKOUT
            .fullScreenCover(
                isPresented: $showAddWorkout,
                onDismiss: { Task { await reloadAll() } }
            ) {
                AddEditWorkoutView()
                    .environmentObject(authService)
            }

            // EDIT EXISTING WORKOUT (by day)
            .fullScreenCover(
                item: Binding(
                    get: { editingDate.map { IdentifiableDate(date: $0) } },
                    set: { editingDate = $0?.date }
                ),
                onDismiss: { Task { await reloadAll() } }
            ) { identifiableDate in
                let date = identifiableDate.date
                let key = calendar.startOfDay(for: date)

                AddEditWorkoutView(
                    workoutDate: date,
                    existingBlocks: groupedBlocks[key] ?? [],
                    existingNote: dateNotes[key]
                )
                .environmentObject(authService)
            }

            // DUPLICATE (pre-filled add, not yet saved)
            .fullScreenCover(
                item: $duplicateContext,
                onDismiss: { Task { await reloadAll() } }
            ) { context in
                AddEditWorkoutView(
                    workoutDate: context.date,
                    existingBlocks: context.blocks,
                    existingNote: context.note
                )
                .environmentObject(authService)
            }

            // INSIGHTS
            .fullScreenCover(isPresented: $showInsights) {
                NavigationStack {
                    InsightsView()
                        .environmentObject(authService)
                }
            }

            .task { await reloadAll() }
        }
    }

    // MARK: - Derived Data

    private var groupedBlocks: [Date: [WorkoutBlock]] {
        Dictionary(grouping: blocks) { calendar.startOfDay(for: $0.date) }
    }

    // MARK: - DATA LOADING

    private func reloadAll() async {
        await MainActor.run { isLoading = true }
        await loadBlocks()
        await loadNotes()
    }

    private func loadBlocks() async {
        guard let uid = authService.user?.uid else {
            await MainActor.run {
                blocks = []
                isLoading = false
            }
            return
        }

        do {
            let fetched = try await firestoreService.fetchBlocks(userId: uid)
            await MainActor.run {
                blocks = fetched
                isLoading = false
            }
        } catch {
            print("Error loading blocks:", error)
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func loadNotes() async {
        guard let uid = authService.user?.uid else {
            await MainActor.run {
                dateNotes = [:]
            }
            return
        }

        var result: [Date: DateNote] = [:]

        for date in groupedBlocks.keys {
            if let note = try? await firestoreService.fetchDateNote(userId: uid, date: date) {
                result[date] = note
            }
        }

        await MainActor.run {
            dateNotes = result
        }
    }

    // MARK: - ACTIONS

    private func deleteDay(for date: Date) {
        let day = calendar.startOfDay(for: date)
        let blocksForDay = groupedBlocks[day] ?? []
        let note = dateNotes[day]

        Task {
            do {
                for block in blocksForDay {
                    if let id = block.id {
                        try await firestoreService.deleteBlock(id: id)
                    }
                }

                if let note = note, let id = note.id {
                    try await firestoreService.deleteDateNote(id: id)
                }

                await reloadAll()
            } catch {
                print("Error deleting day:", error)
            }
        }
    }

    private func duplicateDay(for date: Date) {
        let day = calendar.startOfDay(for: date)
        let blocksForDay = groupedBlocks[day] ?? []
        let noteForDay = dateNotes[day]

        guard !blocksForDay.isEmpty else { return }

        // New date for the duplicate – today.
        // Change to `day` if you want same-date duplicate instead.
        let newDay = calendar.startOfDay(for: Date())

        // Clone blocks with nil IDs so they save as *new* blocks
        let clonedBlocks: [WorkoutBlock] = blocksForDay.map { block in
            WorkoutBlock(
                id: nil,                             // 👈 important: no id
                userId: block.userId,
                date: newDay,                        // prefill date as today
                createdAt: block.createdAt,
                name: block.name,
                details: block.details,
                isTracked: block.isTracked,
                trackType: block.trackType,
                trackValue: block.trackValue,
                trackUnit: block.trackUnit
            )
        }

        // Clone note (if any) with nil ID and new date
        let clonedNote: DateNote? = noteForDay.map { original in
            DateNote(
                id: nil,                             // 👈 new note
                userId: original.userId,
                date: newDay,
                note: original.note
            )
        }

        // Open AddEdit prefilled with this duplicated context (no writes yet)
        duplicateContext = DuplicateContext(
            date: newDay,
            blocks: clonedBlocks,
            note: clonedNote
        )
    }
}

// MARK: - LIST + ROWS

struct WorkoutsList: View {
    let groupedBlocks: [Date: [WorkoutBlock]]
    let dateNotes: [Date: DateNote]
    let onEditDay: (Date) -> Void
    let onDuplicateDay: (Date) -> Void
    let onDeleteDay: (Date) -> Void

    var body: some View {
        List {
            ForEach(sortedDates, id: \.self) { date in
                WorkoutDayCard(
                    date: date,
                    note: dateNotes[date]?.note,
                    blocks: groupedBlocks[date] ?? [],
                    onTap: { onEditDay(date) },
                    onDuplicate: { onDuplicateDay(date) },
                    onDelete: { onDeleteDay(date) }
                )
                .workoutListRow(bottom: WorkoutListStyle.dividerBottom)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.top, Spacing.md)
    }

    private var sortedDates: [Date] {
        groupedBlocks.keys
            .filter { !(groupedBlocks[$0] ?? []).isEmpty }
            .sorted(by: >)
    }
}

// MARK: - DAY CARD (entire card swipes)

struct WorkoutDayCard: View {
    let date: Date
    let note: String?
    let blocks: [WorkoutBlock]
    let onTap: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {

                // DATE + OPTIONAL NOTE
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(WorkoutListStyle.dateFont)
                        .foregroundColor(Color.brand.textPrimary)

                    if let note, !note.isEmpty {
                        Text(note)
                            .font(WorkoutListStyle.noteFont)
                            .foregroundColor(Color.brand.textSecondary)
                            .italic()
                    }
                }
                .padding(.bottom,
                         (note?.isEmpty ?? true)
                         ? WorkoutListStyle.dateBottomNoNote
                         : WorkoutListStyle.dateBottom
                )

                // BLOCKS
                let sortedBlocks = blocks.sorted { $0.createdAt < $1.createdAt }
                ForEach(Array(sortedBlocks.enumerated()), id: \.element.id) { index, block in
                    let isLast = index == sortedBlocks.count - 1

                    BlockCard(block: block, onTap: onTap)

                    if !isLast {
                        Spacer().frame(height: WorkoutListStyle.blockBottom)
                    }
                }

                // DIVIDER
                Color.brand.border
                    .frame(height: 1)
                    .padding(.top, WorkoutListStyle.lastBlockBottom)
            }
            .padding(.horizontal, WorkoutListStyle.horizontalPadding)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }

            Button(action: onDuplicate) {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            .tint(Color.brand.primary)
        }
    }
}

// MARK: - BLOCK CARD

struct BlockCard: View {
    let block: WorkoutBlock
    let onTap: () -> Void

    private var metricText: String? {
        guard let value = block.trackValue,
              let type = block.trackType
        else { return nil }

        switch type {
        case .weight:
            let unit = block.trackUnit ?? "kg"
            let formatted =
                value.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(value))"
                : "\(value)"
            return "\(formatted)\(unit)"

        case .time:
            let minutes = Int(value) / 60
            let seconds = Int(value) % 60
            return seconds == 0
            ? "\(minutes) mins"
            : String(format: "%d:%02d mins", minutes, seconds)

        case .none:
            return nil
        }
    }

    private var detailsText: String? {
        let trimmed = block.details.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WorkoutListStyle.blockLineSpacing) {

            // NAME + TRACKED DOT
            HStack(spacing: 6) {
                Text(block.name)
                    .font(WorkoutListStyle.blockTitleFont)
                    .foregroundColor(Color.brand.textPrimary)

                if block.isTracked {
                    Circle()
                        .fill(Color.brand.primary)
                        .frame(width: 7, height: 7)
                }
            }

            // METRIC — DETAILS
            if metricText != nil || detailsText != nil {
                HStack(spacing: 6) {

                    if let metricText {
                        Text(metricText)
                            .font(WorkoutListStyle.blockDetailsFont)
                            .foregroundColor(Color.brand.textPrimary)
                    }

                    if metricText != nil && detailsText != nil {
                        Text("—")
                            .font(WorkoutListStyle.blockDetailsFont)
                            .foregroundColor(Color.brand.textSecondary)
                    }

                    if let detailsText {
                        Text(detailsText)
                            .font(WorkoutListStyle.blockDetailsFont)
                            .foregroundColor(Color.brand.textSecondary)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - MODIFIER

private struct WorkoutListRowModifier: ViewModifier {
    let bottom: CGFloat

    func body(content: Content) -> some View {
        content
            .listRowSeparator(.hidden)
            .listRowInsets(.init(top: 0, leading: 0, bottom: bottom, trailing: 0))
            .listRowBackground(Color.brand.background)
    }
}

private extension View {
    func workoutListRow(bottom: CGFloat) -> some View {
        modifier(WorkoutListRowModifier(bottom: bottom))
    }
}
