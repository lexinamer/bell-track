import SwiftUI

struct TrainingView: View {

    @StateObject private var blocksVM = BlocksViewModel()
    @StateObject private var workoutsVM = WorkoutsViewModel()
    @State private var selectedBlock: Block?
    @State private var showingAllBlocks = false
    @State private var showingCreateMenu = false
    @State private var showingCreateOptions = false
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
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        return workoutsVM.sortedWorkouts.filter { $0.date >= cutoff }
    }

    private var isInitialLoading: Bool {
        (blocksVM.isLoading || workoutsVM.isLoading)
        && blocksVM.blocks.isEmpty
        && workoutsVM.workouts.isEmpty
    }

    // MARK: - View

    var body: some View {
        ZStack {
            Color.brand.background
                .ignoresSafeArea()
            if isInitialLoading {
                ProgressView()
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

        // MARK: - Workout Sheet

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

        // MARK: - Block Sheet

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
        .task {
            await blocksVM.load()
            await workoutsVM.load()
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
                .foregroundColor(.primary)
            }
            .padding(.horizontal)

            if activeBlocks.isEmpty {
                emptyBlocksState
                    .padding(.horizontal)
            } else {
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
    }

    private var emptyBlocksState: some View {
        VStack(spacing: Theme.Space.sm) {
            Text("No active blocks")
                .foregroundColor(.secondary)
            Button("New Block") {
                showingNewBlock = true
            }
        }
    }

    // MARK: - Recent Workouts

    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("Recent Workouts")
                .font(Theme.Font.sectionTitle)
                .padding(.horizontal)
            if recentWorkouts.isEmpty {
                Text("No workouts in past 30 days")
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
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
                .padding(.top, Theme.Space.sm)
            }
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
