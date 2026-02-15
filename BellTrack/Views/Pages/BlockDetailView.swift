import SwiftUI

struct BlockDetailView: View {

    let block: Block
    @ObservedObject var blocksVM: BlocksViewModel

    @StateObject private var workoutsVM = WorkoutsViewModel()
    @Environment(\.dismiss) private var dismiss

    // MARK: - Actions

    @State private var showingEdit = false
    @State private var showingDeleteAlert = false
    @State private var showingCompleteAlert = false
    @State private var editingWorkout: Workout?
    @State private var workoutToDelete: Workout?

    // MARK: - Derived

    private var workouts: [Workout] {
        workoutsVM.workouts(for: block.id)
    }

    private var totalWorkouts: Int {
        workouts.count
    }

    private var templateCount: Int {
        blocksVM.templatesForBlock(block.id).count
    }

    private var totalSets: Int {
        workouts
            .flatMap { $0.logs }
            .compactMap { $0.sets }
            .reduce(0, +)
    }

    // MARK: - View

    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: Theme.Space.lg
            ) {

                headerSection

                statsRow

                workoutsSection
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, Theme.Space.md)
        }
        .background(Color.brand.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarMenu }
        .task {
            await workoutsVM.load()
        }

        // MARK: - Edit Workout Sheet

        .fullScreenCover(item: $editingWorkout) { workout in
            WorkoutFormView(
                workout: workout,
                onSave: {
                    editingWorkout = nil
                    Task { await workoutsVM.load() }
                },
                onCancel: {
                    editingWorkout = nil
                }
            )
        }

        // MARK: - Edit Block Sheet

        .fullScreenCover(isPresented: $showingEdit) {
            BlockFormView(
                block: block,
                blocksVM: blocksVM,
                onSave: { name, startDate, endDate, notes, _, _ in
                    Task {
                        await blocksVM.saveBlock(
                            id: block.id,
                            name: name,
                            startDate: startDate,
                            endDate: endDate,
                            notes: notes,
                            colorIndex: nil
                        )
                        showingEdit = false
                    }
                },
                onCancel: {
                    showingEdit = false
                }
            )
        }

        // MARK: - Delete Workout Alert

        .alert("Delete Workout?", isPresented: Binding(
            get: { workoutToDelete != nil },
            set: { if !$0 { workoutToDelete = nil } }
        )) {

            Button("Cancel", role: .cancel) {}

            Button("Delete", role: .destructive) {
                if let workout = workoutToDelete {
                    Task {
                        await workoutsVM.deleteWorkout(id: workout.id)
                        await workoutsVM.load()
                    }
                }
            }

        } message: {
            Text("This will permanently delete this workout.")
        }

        // MARK: - Delete Block Alert

        .alert("Delete Block?", isPresented: $showingDeleteAlert) {

            Button("Cancel", role: .cancel) { }

            Button("Delete", role: .destructive) {
                Task {
                    await blocksVM.deleteBlock(id: block.id)
                    dismiss()
                }
            }

        } message: {
            Text("This cannot be undone.")
        }

        // MARK: - Complete Block Alert

        .alert("Complete Block?", isPresented: $showingCompleteAlert) {

            Button("Cancel", role: .cancel) { }

            Button("Complete") {
                Task {
                    await blocksVM.completeBlock(id: block.id)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {

        VStack(alignment: .leading, spacing: Theme.Space.sm) {

            Text(block.name)
                .font(Theme.Font.pageTitle)
                .foregroundColor(Color.brand.textPrimary)

            Text(progressText)
                .font(Theme.Font.cardSecondary)
                .foregroundColor(Color.brand.textSecondary)

            if let goal = block.notes, !goal.isEmpty {
                Text("\(Text("Goal: ").fontWeight(.semibold))\(Text(goal))")
                    .foregroundColor(Color.brand.textPrimary)
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {

        HStack(spacing: 0) {

            statItem(value: totalWorkouts, label: "Workouts")

            Divider()
                .frame(height: 32)
            statItem(value: templateCount, label: "Templates")

            Divider()
                .frame(height: 32)

            statItem(value: totalSets, label: "Sets")
        }
        .padding(.vertical, Theme.Space.smp)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .fill(Color.brand.surface)
        )
    }
    
    private func statItem(value: Int, label: String) -> some View {
        VStack(spacing: Theme.Space.xs) {
            Text("\(value)")
                .font(Theme.Font.statValue)
                .foregroundColor(Color.brand.textPrimary)

            Text(label)
                .font(Theme.Font.statLabel)
                .foregroundColor(Color.brand.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Workouts Section

    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            if workouts.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: Theme.Space.sm) {
                    ForEach(workouts) { workout in
                        WorkoutCard(
                            workout: workout,
                            badgeColor: ColorTheme.blockColor,
                            onEdit: {
                                editingWorkout = workout
                            },
                            onDuplicate: {
                                editingWorkout = workoutsVM.duplicate(workout)
                            },
                            onDelete: {
                                workoutToDelete = workout
                            }
                        )
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Space.sm) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: Theme.IconSize.lg))
                .foregroundColor(Color.brand.textSecondary)
            Text("No workouts yet")
                .font(Theme.Font.emptyStateTitle)
                .foregroundColor(Color.brand.textPrimary)
            Text("Workouts assigned to this block will appear here.")
                .font(Theme.Font.emptyStateDescription)
                .foregroundColor(Color.brand.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.lg)
    }

    // MARK: - Toolbar Menu

    private var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    showingEdit = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                if block.completedDate == nil {
                    Button {
                        showingCompleteAlert = true
                    } label: {
                        Label("Complete", systemImage: "checkmark.circle")
                    }
                }
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
        }
    }

    // MARK: - Progress Text

    private var progressText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let start = formatter.string(from: block.startDate)

        if let endDate = block.endDate {
            let end = formatter.string(from: endDate)
            return "\(start) – \(end)"
        } else {
            return "Started \(start)"
        }
    }
}
