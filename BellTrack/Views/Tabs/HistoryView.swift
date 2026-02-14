import SwiftUI

struct HistoryView: View {

    @StateObject private var workoutsVM = WorkoutsViewModel()
    @State private var editingWorkout: Workout?
    @State private var workoutToDelete: Workout?

    // MARK: - Derived

    private var workoutsByMonth: [(Date, [Workout])] {
        let grouped = Dictionary(
            grouping: workoutsVM.sortedWorkouts
        ) {
            Calendar.current.date(
                from: Calendar.current.dateComponents(
                    [.year, .month],
                    from: $0.date
                )
            )!
        }
        return grouped
            .map { ($0.key, $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.0 > $1.0 }
    }

    private var isEmpty: Bool {
        workoutsVM.sortedWorkouts.isEmpty && !workoutsVM.isLoading
    }

    // MARK: - View

    var body: some View {
        ZStack {
            Color.brand.background
                .ignoresSafeArea()
            if workoutsVM.isLoading && workoutsVM.workouts.isEmpty {
                ProgressView()
            } else if isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(
                        alignment: .leading,
                        spacing: Theme.Space.xl
                    ) {
                        ForEach(workoutsByMonth, id: \.0) { month, workouts in
                            monthSection(month, workouts: workouts)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("History")
        .task {
            await workoutsVM.load()
        }

        // MARK: - Edit Sheet

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

        // MARK: - Delete Alert

        .alert(
            "Delete Workout?",
            isPresented: deleteBinding
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let workout = workoutToDelete {
                    Task {
                        await workoutsVM.deleteWorkout(id: workout.id)
                    }
                }
            }

        } message: {
            Text("This will permanently delete this workout.")
        }
    }

    // MARK: - Month Section

    private func monthSection(
        _ month: Date,
        workouts: [Workout]
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: Theme.Space.md
        ) {
            Text(
                month,
                format: .dateTime.month(.abbreviated).year()
            )
            .font(Theme.Font.sectionTitle)
            .padding(.horizontal)
            LazyVStack(
                spacing: Theme.Space.md
            ) {
                ForEach(workouts) { workout in
                    WorkoutCard(
                        workout: workout,
                        badgeColor: workoutsVM.badgeColor(for: workout),
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
            .padding(.horizontal)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(
            spacing: Theme.Space.md
        ) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: Theme.IconSize.xl))
                .foregroundColor(.secondary)
            Text("No workout history")
                .font(Theme.Font.emptyStateTitle)
            Text("Your completed workouts will appear here.")
                .font(Theme.Font.emptyStateDescription)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Binding

    private var deleteBinding: Binding<Bool> {
        Binding(
            get: { workoutToDelete != nil },
            set: {
                if !$0 {
                    workoutToDelete = nil
                }
            }
        )
    }
}

