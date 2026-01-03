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
}

// MARK: - MAIN VIEW

struct WorkoutsListView: View {
    @EnvironmentObject var authService: AuthService

    @State private var blocks: [WorkoutBlock] = []
    @State private var isLoading = true
    @State private var showAddWorkout = false
    @State private var editingDate: Date?
    @State private var duplicateContext: DuplicateContext?

    private let firestoreService = FirestoreService()
    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brand.background.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                } else if groupedBlocks.isEmpty {
                    VStack(spacing: Spacing.sm) {
                        Text("No workouts yet")
                            .font(.system(size: Typography.lg, weight: .semibold))
                            .foregroundColor(Color.brand.textPrimary)

                        Text("Tap + to add your first workout.")
                            .font(.system(size: Typography.sm))
                            .foregroundColor(Color.brand.textSecondary)
                    }
                } else {
                    WorkoutsList(
                        groupedBlocks: groupedBlocks,
                        onEditDay: { date in editingDate = date },
                        onDuplicateDay: { date in duplicateDay(for: date) },
                        onDeleteDay: { date in deleteDay(for: date) }
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Workouts")
                        .font(.system(size: Typography.lg, weight: .semibold))
                        .foregroundColor(Color.brand.textPrimary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddWorkout = true } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brand.primary)
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
                    existingBlocks: groupedBlocks[key] ?? []
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
                    existingBlocks: context.blocks
                )
                .environmentObject(authService)
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

    // MARK: - ACTIONS

    private func deleteDay(for date: Date) {
        let day = calendar.startOfDay(for: date)
        let blocksForDay = groupedBlocks[day] ?? []

        Task {
            do {
                for block in blocksForDay {
                    if let id = block.id {
                        try await firestoreService.deleteBlock(id: id)
                    }
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

        guard !blocksForDay.isEmpty else { return }

        let newDay = calendar.startOfDay(for: Date())

        let clonedBlocks: [WorkoutBlock] = blocksForDay.map { block in
            WorkoutBlock(
                id: nil,
                userId: block.userId,
                date: newDay,
                createdAt: block.createdAt,
                name: block.name,
                details: block.details,
                isTracked: block.isTracked,
                trackType: block.trackType,
                trackValue: block.trackValue,
                trackUnit: block.trackUnit
            )
        }

        duplicateContext = DuplicateContext(
            date: newDay,
            blocks: clonedBlocks
        )
    }
}

// MARK: WORKOUTS LIST
struct WorkoutsList: View {
    let groupedBlocks: [Date: [WorkoutBlock]]
    let onEditDay: (Date) -> Void
    let onDuplicateDay: (Date) -> Void
    let onDeleteDay: (Date) -> Void

    var body: some View {
        List {
            ForEach(sortedDates, id: \.self) { date in
                WorkoutDayCard(
                    date: date,
                    blocks: groupedBlocks[date] ?? [],
                    onEdit: { onEditDay(date) },
                    onDuplicate: { onDuplicateDay(date) },
                    onDelete: { onDeleteDay(date) }
                )
                .listRowSeparator(.visible)
                .listRowInsets(.init(
                    top: 0,
                    leading: 0,
                    bottom: 0,
                    trailing: 0
                ))
                .listRowBackground(Color.brand.surface)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var sortedDates: [Date] {
        groupedBlocks.keys
            .filter { !(groupedBlocks[$0] ?? []).isEmpty }
            .sorted(by: >)
    }
}

// MARK: - DAY CARD

struct WorkoutDayCard: View {
    let date: Date
    let blocks: [WorkoutBlock]
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            // card background
            Color.white

            VStack(alignment: .leading, spacing: 0) {

                // DATE 
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(TextStyles.heading)
                    .foregroundColor(Color.brand.textPrimary)

                // BLOCKS
                let sortedBlocks = blocks.sorted { $0.createdAt < $1.createdAt }

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(sortedBlocks.enumerated()), id: \.offset) { index, block in
                        BlockCard(block: block)
                            .padding(.top,
                                index == 0
                                ? WorkoutListStyle.dateToFirstBlock
                                : WorkoutListStyle.betweenBlocks
                            )
                    }
                }
            }
            .padding(.horizontal, WorkoutListStyle.cardHorizontalPadding)
            .padding(.vertical, WorkoutListStyle.cardTopBottomPadding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }

            Button(action: onDuplicate) {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            .tint(Color.brand.primary)

            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            .tint(Color.brand.textPrimary)
        }
    }
}

// MARK: - BLOCK CARD

struct BlockCard: View {
    let block: WorkoutBlock

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

        case .reps:
            let formatted =
                value.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(value))"
                : "\(value)"
            return "\(formatted) reps"
        }
    }

    private var detailsText: String? {
        let trimmed = block.details.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WorkoutListStyle.blockLineSpacing) {

            // Movement name
            Text(block.name)
                .font(TextStyles.bodyStrong)
                .foregroundColor(Color.brand.textPrimary)

            // Metric + details line
            if metricText != nil || detailsText != nil {
                HStack(spacing: 4) {
                    if let metricText {
                        Text(metricText)
                            .foregroundColor(Color.brand.textSecondary)
                    }

                    if let detailsText {
                        Text("•")
                            .foregroundColor(Color.brand.textSecondary)

                        Text(detailsText)
                            .foregroundColor(Color.brand.textSecondary)
                    }
                }
                .font(TextStyles.body)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - MODIFIER
extension View {
    @ViewBuilder
    func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
