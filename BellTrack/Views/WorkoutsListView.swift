import SwiftUI
import FirebaseAuth

// For full-screen edit routing
struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}

// MARK: - MAIN VIEW

struct WorkoutsListView: View {
    @EnvironmentObject var authService: AuthService

    @State private var blocks: [WorkoutBlock] = []
    @State private var dateNotes: [Date: DateNote] = [:]

    @State private var isLoading = true
    @State private var showAddWorkout = false
    @State private var editingDate: Date?

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
                ToolbarItem(placement: .principal) {
                    Text("Workouts")
                        .font(.system(size: Typography.xl, weight: .semibold))
                        .foregroundColor(Color.brand.textPrimary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddWorkout = true } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brand.secondary)
                }
            }
            .navigationBarTitleDisplayMode(.inline)

            .fullScreenCover(isPresented: $showAddWorkout, onDismiss: { Task { await reloadAll() } }) {
                AddEditWorkoutView()
            }

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
        await loadBlocks()
        await loadNotes()
    }

    private func loadBlocks() async {
        guard let uid = authService.user?.uid else { return }
        do {
            let fetched = try await firestoreService.fetchBlocks(userId: uid)
            await MainActor.run {
                blocks = fetched
                isLoading = false
            }
        } catch {
            print("Error loading blocks:", error)
        }
    }

    private func loadNotes() async {
        guard let uid = authService.user?.uid else { return }

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
        let note = dateNotes[day]

        guard let uid = authService.user?.uid else { return }
        guard !blocksForDay.isEmpty else { return }

        // Duplicate to TODAY so it's obvious
        let newDay = calendar.startOfDay(for: Date())

        Task {
            do {
                for block in blocksForDay {
                    try await firestoreService.saveBlock(
                        WorkoutBlock(
                            id: nil,
                            userId: uid,
                            date: newDay,
                            createdAt: Date(),
                            name: block.name,
                            details: block.details,
                            isTracked: block.isTracked,
                            trackType: block.trackType,
                            trackValue: block.trackValue,
                            trackUnit: block.trackUnit
                        )
                    )
                }

                if let note = note {
                    try await firestoreService.saveDateNote(
                        DateNote(
                            id: nil,
                            userId: uid,
                            date: newDay,
                            note: note.note
                        )
                    )
                }

                await reloadAll()
            } catch {
                print("Error duplicating day:", error)
            }
        }
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
                Section {
                    DateHeader(
                        date: date,
                        note: dateNotes[date]?.note,
                        onTap: { onEditDay(date) },
                        onDuplicate: { onDuplicateDay(date) },
                        onDelete: { onDeleteDay(date) }
                    )

                    BlockRows(
                        blocks: groupedBlocks[date] ?? [],
                        onTapDay: { onEditDay(date) }
                    )

                    Color.brand.border
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                        .workoutListRow(
                            bottom: WorkoutListStyle.dividerBottom
                        )
                }
                .listSectionSpacing(0)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.top, Spacing.sm)
    }

    private var sortedDates: [Date] {
        groupedBlocks.keys.sorted(by: >)
    }
}

// MARK: - DATE HEADER (whole-day swipe)

struct DateHeader: View {
    let date: Date
    let note: String?
    let onTap: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
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
            .padding(.horizontal, WorkoutListStyle.horizontalPadding)
            .padding(.bottom,
                     (note?.isEmpty ?? true)
                     ? WorkoutListStyle.dateBottomNoNote
                     : WorkoutListStyle.dateBottom
            )
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

// MARK: - BLOCK ROWS

struct BlockRows: View {
    let blocks: [WorkoutBlock]
    let onTapDay: () -> Void

    var body: some View {
        ForEach(Array(blocks.sorted(by: { $0.createdAt < $1.createdAt }).enumerated()),
                id: \.element.id) { index, block in

            let isLast = index == blocks.count - 1

            BlockCard(block: block, onTap: onTapDay)
                .workoutListRow(
                    bottom: isLast
                    ? WorkoutListStyle.lastBlockBottom
                    : WorkoutListStyle.blockBottom
                )
        }
    }
}

// MARK: - BLOCK CARD

struct BlockCard: View {
    let block: WorkoutBlock
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: WorkoutListStyle.blockLineSpacing) {

            HStack(spacing: 5) {
                Text(block.name)
                    .font(WorkoutListStyle.blockTitleFont)
                    .foregroundColor(Color.brand.textPrimary)

                if block.isTracked {
                    Circle()
                        .fill(Color.brand.primary)
                        .frame(width: 7, height: 7)
                }
            }

            HStack(spacing: 6) {
                if let metric = formattedMetric {
                    Text(metric)
                        .font(WorkoutListStyle.blockTitleFont)
                        .foregroundColor(Color.brand.textPrimary)
                }

                if !block.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(block.details)
                        .font(WorkoutListStyle.blockDetailsFont)
                        .foregroundColor(Color.brand.textSecondary)
                }
            }
        }
        .padding(.horizontal, WorkoutListStyle.horizontalPadding)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    private var formattedMetric: String? {
        guard let value = block.trackValue,
              let type = block.trackType
        else { return nil }

        switch type {
        case .weight:
            let unit = block.trackUnit ?? "kg"
            return value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))\(unit)"
            : "\(value)\(unit)"

        case .time:
            let mins = Int(value) / 60
            let secs = Int(value) % 60
            return secs == 0 ? "\(mins) mins" : String(format: "%d:%02d mins", mins, secs)

        case .none:
            return nil
        }
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
