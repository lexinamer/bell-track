import SwiftUI

struct TrainingView: View {

    @StateObject private var blocksVM = BlocksViewModel()
    @StateObject private var workoutsVM = WorkoutsViewModel()

    // Navigation
    @State private var selectedBlock: Block?
    @State private var showingAllBlocks = false

    // Create menu
    @State private var showingCreateOptions = false

    // Sheets
    @State private var showingNewWorkout = false
    @State private var showingNewBlock = false
    @State private var editingWorkout: Workout?
    @State private var workoutToDelete: Workout?

    // MARK: - Derived

    private var activeBlocks: [Block] {
        blocksVM.blocks
            .filter { $0.completedDate == nil && $0.startDate <= Date() }
            .sorted { $0.startDate > $1.startDate }
    }

    private var recentWorkouts: [Workout] {
        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -30,
            to: Date()
        )!

        return workoutsVM.sortedWorkouts
            .filter { $0.date >= cutoff }
    }

    private var isInitialLoading: Bool {
        (blocksVM.isLoading || workoutsVM.isLoading)
        && blocksVM.blocks.isEmpty
        && workoutsVM.workouts.isEmpty
    }

    private var isEmptyState: Bool {
        activeBlocks.isEmpty && recentWorkouts.isEmpty
    }

    // MARK: - View

    var body: some View {

        ZStack {

            Color.brand.background
                .ignoresSafeArea()

            if isInitialLoading {

                ProgressView()

            } else if isEmptyState {

                emptyTrainingState

            } else {

                ScrollView {

                    LazyVStack(
                        alignment: .leading,
                        spacing: Theme.Space.xl
                    ) {

                        blocksSection

                        recentWorkoutsSection
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("Training")

        // MARK: - Toolbar

        .toolbar {

            ToolbarItem(placement: .topBarTrailing) {

                Button {
                    showingCreateOptions = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }

        .confirmationDialog(
            "Create",
            isPresented: $showingCreateOptions,
            titleVisibility: .hidden
        ) {

            Button("Log Workout") {
                showingNewWorkout = true
            }

            Button("New Block") {
                showingNewBlock = true
            }
        }

        // MARK: - Navigation

        .navigationDestination(item: $selectedBlock) {
            BlockDetailView(block: $0)
        }

        .navigationDestination(isPresented: $showingAllBlocks) {
            AllBlocksView(blocksVM: blocksVM)
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

        // MARK: - New Workout Sheet

        .fullScreenCover(isPresented: $showingNewWorkout) {

            WorkoutFormView(
                workout: nil,
                onSave: {
                    showingNewWorkout = false
                    Task { await workoutsVM.load() }
                },
                onCancel: {
                    showingNewWorkout = false
                }
            )
        }

        // MARK: - New Block Sheet

        .fullScreenCover(isPresented: $showingNewBlock) {

            BlockFormView(
                blocksVM: blocksVM,
                onSave: { name, start, type, duration, notes, color in

                    Task {

                        await blocksVM.saveBlock(
                            id: nil,
                            name: name,
                            startDate: start,
                            type: type,
                            durationWeeks: duration,
                            notes: notes,
                            colorIndex: color
                        )

                        showingNewBlock = false
                    }
                },
                onCancel: {
                    showingNewBlock = false
                }
            )
        }

        // MARK: - Delete Alert

        .alert("Delete Workout?", isPresented: deleteWorkoutBinding) {

            Button("Cancel", role: .cancel) {}

            Button("Delete", role: .destructive) {

                if let workout = workoutToDelete {

                    Task {
                        await workoutsVM.deleteWorkout(id: workout.id)
                        await workoutsVM.load()
                    }
                }
            }
        }

        // MARK: - Load

        .task {

            await blocksVM.load()
            await workoutsVM.load()
        }
    }

    // MARK: - Empty State

    private var emptyTrainingState: some View {

        VStack(spacing: Theme.Space.lg) {

            Spacer()

            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 44))
                .foregroundColor(.secondary)

            Text("Start your training")
                .font(Theme.Font.emptyStateTitle)

            Text("Create a block to organize your training, then log workouts.")
                .font(Theme.Font.emptyStateDescription)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Space.lg)

            VStack(spacing: Theme.Space.sm) {

                Button {
                    showingNewBlock = true
                } label: {

                    Text("Create Block")
                        .font(Theme.Font.buttonPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Space.sm)
                        .background(Color.brand.primary)
                        .foregroundColor(.white)
                        .cornerRadius(Theme.Radius.md)
                }

                Button {
                    showingNewWorkout = true
                } label: {

                    Text("Log Workout")
                        .font(Theme.Font.buttonPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Space.sm)
                }
            }
            .padding(.horizontal, Theme.Space.xl)

            Spacer()
        }
    }

    // MARK: - Blocks Section

    private var blocksSection: some View {

        VStack(alignment: .leading, spacing: Theme.Space.sm) {

            HStack {

                Text("Active Blocks")
                    .font(Theme.Font.sectionTitle)

                Spacer()

                Button {
                    showingAllBlocks = true
                } label: {
                    Image(systemName: "square.stack")
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal)

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: Theme.Space.md
            ) {

                ForEach(activeBlocks) { block in

                    BlockCard(
                        block: block,
                        workoutCount: blocksVM.workoutCounts[block.id],
                        templateCount: blocksVM.templatesForBlock(block.id).count,
                        onEdit: {},
                        onComplete: {},
                        onDelete: {}
                    )
                    .onTapGesture {
                        selectedBlock = block
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Recent Workouts Section

    private var recentWorkoutsSection: some View {

        VStack(alignment: .leading, spacing: Theme.Space.sm) {

            Text("Recent Workouts")
                .font(Theme.Font.sectionTitle)
                .padding(.horizontal)

            LazyVStack(spacing: Theme.Space.md) {

                ForEach(recentWorkouts) { workout in

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

    // MARK: - Delete Binding

    private var deleteWorkoutBinding: Binding<Bool> {

        Binding(
            get: { workoutToDelete != nil },
            set: { if !$0 { workoutToDelete = nil } }
        )
    }
}
