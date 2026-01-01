import SwiftUI
import FirebaseAuth

// MARK: - Identifiable wrapper for full-screen edit by date

struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}

// MARK: - Root Workouts List Screen

struct WorkoutsListView: View {
    @EnvironmentObject var authService: AuthService

    @State private var blocks: [WorkoutBlock] = []
    @State private var showAddWorkout = false
    @State private var editingDate: Date?
    @State private var isLoading = true
    @State private var dateNotes: [Date: DateNote] = [:]

    private let firestoreService = FirestoreService()
    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brand.background.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                } else if blocks.isEmpty {
                    emptyState
                } else {
                    WorkoutsList(
                        groupedBlocks: groupedBlocks,
                        dateNotes: dateNotes,
                        onEditDay: { date in
                            editingDate = date
                        },
                        onDuplicateDay: { date in
                            // For now, duplicate behaves like "edit this day";
                            // you can later change this to pre-fill a new date.
                            editingDate = date
                        },
                        onDeleteDay: { date in
                            deleteDay(for: date)
                        }
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .fullScreenCover(isPresented: $showAddWorkout, onDismiss: {
                Task { await reloadAll() }
            }) {
                AddEditWorkoutView()
            }
            .fullScreenCover(
                item: Binding(
                    get: { editingDate.map { IdentifiableDate(date: $0) } },
                    set: { editingDate = $0?.date }
                ),
                onDismiss: {
                    Task { await reloadAll() }
                }
            ) { identifiableDate in
                let date = identifiableDate.date
                let key = calendar.startOfDay(for: date)
                let blocksForDate = groupedBlocks[key] ?? []
                let noteForDate = dateNotes[key]

                AddEditWorkoutView(
                    workoutDate: date,
                    existingBlocks: blocksForDate,
                    existingNote: noteForDate
                )
            }
            .task {
                await reloadAll()
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Text("No workouts yet")
                .font(.system(size: Typography.lg))
                .foregroundColor(Color.brand.textSecondary)

            Text("Tap + to add your first workout")
                .font(.system(size: Typography.sm))
                .foregroundColor(Color.brand.textSecondary)
        }
    }

    private var groupedBlocks: [Date: [WorkoutBlock]] {
        Dictionary(grouping: blocks) { block in
            calendar.startOfDay(for: block.date)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("Workouts")
                .font(.system(size: Typography.xl, weight: .semibold))
                .foregroundColor(Color.brand.textPrimary)
        }

        ToolbarItem(placement: .topBarLeading) {
            Menu {
                if let email = authService.user?.email {
                    Label(email, systemImage: "")
                        .labelStyle(.titleOnly)
                }

                Divider()

                Button(role: .destructive) {
                    logOut()
                } label: {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: Typography.xl))
            }
            .tint(Color.brand.textPrimary)
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showAddWorkout = true
            } label: {
                Label("plus", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brand.secondary)
        }
    }

    // MARK: - Loading

    private func reloadAll() async {
        await loadBlocks()
        await loadDateNotes()
    }

    private func loadBlocks() async {
        guard let userId = authService.user?.uid else {
            await MainActor.run {
                blocks = []
                isLoading = false
            }
            return
        }

        do {
            let fetched = try await firestoreService.fetchBlocks(userId: userId)
            await MainActor.run {
                blocks = fetched
                isLoading = false
            }
        } catch {
            print("Error loading blocks: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func loadDateNotes() async {
        guard let userId = authService.user?.uid else {
            await MainActor.run { dateNotes = [:] }
            return
        }

        let dates = Array(groupedBlocks.keys)
        var notes: [Date: DateNote] = [:]

        for date in dates {
            if let note = try? await firestoreService.fetchDateNote(userId: userId, date: date) {
                notes[calendar.startOfDay(for: date)] = note
            }
        }

        await MainActor.run {
            dateNotes = notes
        }
    }

    // MARK: - Actions

    private func deleteBlock(_ block: WorkoutBlock) {
        guard let id = block.id else { return }

        Task {
            do {
                try await firestoreService.deleteBlock(id: id)
                await reloadAll()
            } catch {
                print("Error deleting block: \(error)")
            }
        }
    }

    private func deleteDay(for date: Date) {
        let day = calendar.startOfDay(for: date)
        let blocksForDay = groupedBlocks[day] ?? []
        let noteForDay = dateNotes[day]

        Task {
            do {
                // Delete all blocks for this day
                for block in blocksForDay {
                    if let id = block.id {
                        try await firestoreService.deleteBlock(id: id)
                    }
                }

                // Delete note for this day, if any
                if let note = noteForDay, let noteId = note.id {
                    try await firestoreService.deleteDateNote(id: noteId)
                }

                await reloadAll()
            } catch {
                print("Error deleting day: \(error)")
            }
        }
    }

    private func logOut() {
        do {
            try authService.signOut()
        } catch {
            print("Error signing out: \(error)")
        }
    }
}

// MARK: - Shared row modifier for list rows

private struct WorkoutListRowModifier: ViewModifier {
    let bottom: CGFloat
    let background: Color

    func body(content: Content) -> some View {
        content
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: bottom, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(background)
    }
}

private extension View {
    func workoutListRow(
        bottom: CGFloat,
        background: Color = Color.brand.background
    ) -> some View {
        modifier(WorkoutListRowModifier(bottom: bottom, background: background))
    }
}

// MARK: - List: sections, header, rows

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
                    // Date + optional note as the first row (no header indent)
                    DateHeader(
                        date: date,
                        note: dateNotes[date]?.note,
                        onTap: { onEditDay(date) },
                        onDuplicate: { onDuplicateDay(date) },
                        onDelete: { onDeleteDay(date) }
                    )
                    .workoutListRow(
                        bottom: 0,
                        background: Color.brand.background
                    )

                    // Blocks – tapping any block edits the whole day
                    BlockRows(
                        blocks: groupedBlocks[date] ?? [],
                        onTapDay: { onEditDay(date) }
                    )

                    // Divider
                    Color.brand.border
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                        .workoutListRow(
                            bottom: WorkoutListSpacing.dividerBottom,
                            background: .clear
                        )

                } header: {
                    // Empty header -> no default inset or extra spacing
                    EmptyView()
                }
                .listSectionSpacing(0)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var sortedDates: [Date] {
        groupedBlocks.keys
            .filter { (groupedBlocks[$0] ?? []).count > 0 }
            .sorted(by: >)
    }
}

// Date + note “row” (tappable to edit the day, swipe for day actions)
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
                    .font(.system(size: Typography.lg, weight: .bold))
                    .foregroundColor(Color.brand.textPrimary)

                if let note, !note.isEmpty {
                    Text("Notes: \(note)")
                        .font(.system(size: Typography.sm))
                        .foregroundColor(Color.brand.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, WorkoutListSpacing.horizontalPadding)
            .padding(
                .bottom,
                (note?.isEmpty ?? true)
                    ? WorkoutListSpacing.dateBottomNoNote
                    : WorkoutListSpacing.dateBottom
            )
            .background(Color.brand.background)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete day", systemImage: "trash")
            }

            Button(action: onDuplicate) {
                Label("Duplicate day", systemImage: "doc.on.doc")
            }
            .tint(Color.brand.primary)
        }
    }
}

// MARK: - Workout block rows

struct BlockCard: View {
    let block: WorkoutBlock
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: WorkoutListSpacing.blockLineSpacing) {
            HStack(spacing: 4) {
                Text(block.name)
                    .font(.system(size: Typography.md, weight: .semibold))
                    .foregroundColor(Color.brand.textPrimary)

                if let trackValue = formattedTrackValue {
                    Text("|")
                        .font(.system(size: Typography.md))
                        .foregroundColor(Color.brand.textSecondary)

                    Text(trackValue)
                        .font(.system(size: Typography.md, weight: .semibold))
                        .foregroundColor(Color.brand.textPrimary)
                }

                if block.isTracked {
                    Circle()
                        .fill(Color.brand.primary)
                        .frame(width: 8, height: 8)
                }
            }

            if !block.details.isEmpty {
                Text(block.details)
                    .font(.system(size: Typography.sm))
                    .foregroundColor(Color.brand.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, WorkoutListSpacing.horizontalPadding)
        .background(Color.brand.background)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }   // no swipe actions here anymore
    }

    private var formattedTrackValue: String? {
        guard let value = block.trackValue, let type = block.trackType else { return nil }

        switch type {
        case .weight:
            let unit = block.trackUnit ?? "kg"
            let formattedValue =
                value.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(value))
                : String(value)
            return "\(formattedValue)\(unit)"

        case .time:
            let minutes = Int(value) / 60
            let seconds = Int(value) % 60
            if minutes > 0 {
                return String(format: "%d:%02d", minutes, seconds)
            } else {
                return "\(seconds)s"
            }

        case .none:
            return nil
        }
    }
}

struct BlockRows: View {
    let blocks: [WorkoutBlock]
    let onTapDay: () -> Void

    var body: some View {
        ForEach(
            Array(blocks.sorted(by: { $0.createdAt < $1.createdAt }).enumerated()),
            id: \.element.id
        ) { index, block in
            let isLastBlock = index == blocks.count - 1

            BlockCard(
                block: block,
                onTap: onTapDay
            )
            .workoutListRow(
                bottom: isLastBlock
                    ? WorkoutListSpacing.lastBlockBottom
                    : WorkoutListSpacing.blockBottom
            )
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleBlocks = [
        WorkoutBlock(
            id: "1",
            userId: "preview",
            date: Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 31))!,
            createdAt: Date(),
            name: "ABC Complex",
            details: "2/3/1 EMOM x20 single",
            isTracked: true,
            trackType: .time,
            trackValue: 150,
            trackUnit: nil
        ),
        WorkoutBlock(
            id: "2",
            userId: "preview",
            date: Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 31))!,
            createdAt: Date().addingTimeInterval(10),
            name: "Swings",
            details: "15 x3 two-handed",
            isTracked: false,
            trackType: .weight,
            trackValue: 20,
            trackUnit: "kg"
        )
    ]

    let dec31 = Calendar.current.startOfDay(
        for: Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 31))!
    )

    let sampleNotes: [Date: DateNote] = [
        dec31: DateNote(
            id: "note1",
            userId: "preview",
            date: dec31,
            note: "Felt strong today!"
        )
    ]

    let grouped = Dictionary(grouping: sampleBlocks) {
        Calendar.current.startOfDay(for: $0.date)
    }

    return NavigationStack {
        WorkoutsList(
            groupedBlocks: grouped,
            dateNotes: sampleNotes,
            onEditDay: { _ in },
            onDuplicateDay: { _ in },
            onDeleteDay: { _ in }
        )
        .background(Color.brand.background.ignoresSafeArea())
    }
}
