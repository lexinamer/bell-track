import SwiftUI

struct BlockDetailView: View {

    let block: Block

    @StateObject private var workoutsVM = WorkoutsViewModel()

    // MARK: - Actions

    @State private var showingEdit = false
    @State private var showingDeleteAlert = false
    @State private var showingCompleteAlert = false
    @State private var editingWorkout: Workout?
    @State private var workoutToDelete: Workout?


    // MARK: - Derived

    private var blockColor: Color {
        ColorTheme.blockColor(for: block.colorIndex)
    }

    private var workouts: [Workout] {
        workoutsVM.workouts(for: block.id)
    }

    private var totalWorkouts: Int {
        workouts.count
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
                spacing: Theme.Space.xl
            ) {

                headerSection

                statsSection

                workoutsSection
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, Theme.Space.md)
        }
        .background(Color.brand.background.ignoresSafeArea())
        .navigationTitle(block.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarMenu }
        .task {
            await workoutsVM.load()
        }
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

        .alert("Delete Block?", isPresented: $showingDeleteAlert) {

            Button("Cancel", role: .cancel) { }

            Button("Delete", role: .destructive) {
                // Hook into BlocksViewModel in parent
            }

        } message: {

            Text("This cannot be undone.")
        }
        .alert("Complete Block?", isPresented: $showingCompleteAlert) {

            Button("Cancel", role: .cancel) { }

            Button("Complete") {
                // Hook into BlocksViewModel in parent
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {

        VStack(
            alignment: .leading,
            spacing: Theme.Space.sm
        ) {

            Text(progressText)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.primary)

            if let goal = block.notes,
               !goal.isEmpty {

                Text(goal)
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {

        VStack(
            alignment: .leading,
            spacing: Theme.Space.md
        ) {
            
            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: Theme.Space.md
            ) {

                statCard(
                    value: totalWorkouts,
                    label: "Workouts"
                )

                statCard(
                    value: totalSets,
                    label: "Total Sets"
                )
            }
        }
    }

    private func statCard(
        value: Int,
        label: String
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: Theme.Space.xs
        ) {

            Text("\(value)")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.primary)

            Text(label)
                .font(Theme.Font.cardSecondary)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(blockColor.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
    }

    // MARK: - Workouts Section

    private var workoutsSection: some View {

        VStack(
            alignment: .leading,
            spacing: Theme.Space.md
        ) {

            if workouts.isEmpty {

                emptyState

            } else {

                LazyVStack(
                    spacing: Theme.Space.sm
                ) {

                    ForEach(workouts) { workout in

                        WorkoutCard(
                            workout: workout,
                            badgeColor: blockColor,
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

        VStack(
            spacing: Theme.Space.sm
        ) {

            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: Theme.IconSize.lg))
                .foregroundColor(.secondary)

            Text("No workouts yet")
                .font(Theme.Font.emptyStateTitle)

            Text("Workouts assigned to this block will appear here.")
                .font(Theme.Font.emptyStateDescription)
                .foregroundColor(.secondary)
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
                        Label("Complete", systemImage: "checkmark")
                    }
                }

                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }

            } label: {

                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18))
            }
        }
    }

    // MARK: - Progress Text

    private var progressText: String {

        switch block.type {

        case .ongoing:

            let weeks =
                Calendar.current.dateComponents(
                    [.weekOfYear],
                    from: block.startDate,
                    to: Date()
                ).weekOfYear ?? 0

            return "Week \(max(1, weeks + 1)) (ongoing)"

        case .duration:

            guard let duration = block.durationWeeks else {
                return ""
            }

            let weeks =
                Calendar.current.dateComponents(
                    [.weekOfYear],
                    from: block.startDate,
                    to: Date()
                ).weekOfYear ?? 0

            let current =
                min(max(1, weeks + 1), duration)

            return "Week \(current) of \(duration)"
        }
    }
}
