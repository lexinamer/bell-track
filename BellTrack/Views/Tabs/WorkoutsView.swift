import SwiftUI

struct WorkoutsView: View {

    @StateObject private var workoutsVM = WorkoutsViewModel()
    @StateObject private var blocksVM = BlocksViewModel()
    @State private var editingWorkout: Workout?
    @State private var workoutToDelete: Workout?
    @State private var selectedTemplate: WorkoutTemplate?

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

    private var activeTemplates: [WorkoutTemplate] {
        let activeBlocks = blocksVM.blocks.filter {
            $0.completedDate == nil && $0.startDate <= Date()
        }
        let activeBlockIds = activeBlocks.map { $0.id }
        return blocksVM.templates
            .filter { activeBlockIds.contains($0.blockId) }
            .sorted { $0.name < $1.name }
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
        .navigationTitle("Workouts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(activeTemplates) { template in
                        Button {
                            selectedTemplate = template
                        } label: {
                            Text(template.name)
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await workoutsVM.load()
            await blocksVM.load()
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

        // MARK: - New Workout Sheet (from template)

        .fullScreenCover(item: $selectedTemplate) { template in
            WorkoutFormView(
                workout: nil,
                template: template,
                onSave: {
                    selectedTemplate = nil
                    Task { await workoutsVM.load() }
                },
                onCancel: {
                    selectedTemplate = nil
                }
            )
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
            .foregroundColor(Color.brand.textPrimary)
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
            Image(systemName: "list.bullet")
                .font(.system(size: Theme.IconSize.xl))
                .foregroundColor(Color.brand.textSecondary)
            Text("No workout history")
                .font(Theme.Font.emptyStateTitle)
                .foregroundColor(Color.brand.textPrimary)
            Text("Your completed workouts will appear here.")
                .font(Theme.Font.emptyStateDescription)
                .foregroundColor(Color.brand.textSecondary)
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
