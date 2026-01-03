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
                        .font(TextStyles.title)
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
                let day = calendar.startOfDay(for: date)

                AddEditWorkoutView(
                    workoutDate: date,
                    existingBlocks: groupedBlocks[day] ?? []
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
        await MainActor.run {
            isLoading = true
        }
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
            await MainActor.run {
                isLoading = false      // ⬅️ important: always stop spinner
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
                loadKg: block.loadKg,
                loadMode: block.loadMode,
                volumeCount: block.volumeCount,
                volumeKind: block.volumeKind
            )
        }

        duplicateContext = DuplicateContext(
            date: newDay,
            blocks: clonedBlocks
        )
    }
}

// MARK: - WORKOUTS LIST

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

// MARK: - DAY CARD (one day, multiple blocks)

struct WorkoutDayCard: View {
    let date: Date
    let blocks: [WorkoutBlock]
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    private var sortedBlocks: [WorkoutBlock] {
        blocks.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CardStyle.sectionSpacing) {
            // Small subtle date label above the movements
            DateBadge(date: date)
                .padding(.bottom, CardStyle.dateToFirstBlock)
            ForEach(sortedBlocks) { block in
                BlockCard(block: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, CardStyle.cardHorizontalPadding)
        .padding(.vertical, CardStyle.cardVerticalPadding)
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


private struct DateBadge: View {
    let date: Date

    // Year only in the previous years
    private var displayStyle: Date.FormatStyle {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let dateYear = calendar.component(.year, from: date)

        if currentYear == dateYear {
            // e.g. "Jan 3"
            return .dateTime.month(.abbreviated).day()
        } else {
            // e.g. "Dec 29, 2025"
            return .dateTime.month(.abbreviated).day().year()
        }
    }

    var body: some View {
        Text(date.formatted(displayStyle))
            .font(TextStyles.subtext)
            .foregroundColor(Color.brand.secondary)
    }
}

// MARK: - BLOCK CARD (single movement row)

struct BlockCard: View {
    let block: WorkoutBlock

    // Load text — e.g. "16kg Single" / "24kg Double"
    private var loadText: String? {
        guard let kg = block.loadKg else { return nil }

        let kgString: String =
            kg.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(kg))"
            : "\(kg)"

        let modeLabel: String
        switch block.loadMode {
        case .single?:
            modeLabel = "Single"
        case .double?:
            modeLabel = "Double"
        case nil:
            modeLabel = ""
        }

        if modeLabel.isEmpty {
            return "\(kgString)kg"
        } else {
            return "\(kgString)kg \(modeLabel)"
        }
    }

    // Volume text — e.g. "30 reps" / "20 rounds"
    private var volumeText: String? {
        guard let value = block.volumeCount,
              let kind = block.volumeKind else { return nil }

        let valueString: String =
            value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : "\(value)"

        let label: String
        switch kind {
        case .reps:
            label = "reps"
        case .rounds:
            label = "rounds"
        }

        return "\(valueString) \(label)"
    }

    // Combined metric line — e.g. "16kg Single • 30 rounds"
    private var metricLine: String? {
        let parts = [loadText, volumeText].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private var detailsText: String? {
        let trimmed = block.details.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CardStyle.blockLineSpacing) {

            // Movement name
            Text(block.name)
                .font(TextStyles.bodyStrong)
                .foregroundColor(Color.brand.textPrimary)

            // Load / volume / details line
            if metricLine != nil || detailsText != nil {
                HStack(spacing: 4) {
                    if let metricLine {
                        Text(metricLine)
                            .foregroundColor(Color.brand.textSecondary)
                    }

                    if let detailsText {
                        if metricLine != nil {
                            Text("•")
                                .foregroundColor(Color.brand.textSecondary)
                        }
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
