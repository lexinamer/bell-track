import SwiftUI

struct TrainingView: View {

    @StateObject private var blocksVM = BlocksViewModel()
    @StateObject private var workoutsVM = WorkoutsViewModel()

    // MARK: - Navigation / Sheet State

    @State private var selectedBlock: Block?

    @State private var showingNewWorkout = false
    @State private var editingWorkout: Workout?
    @State private var workoutToDelete: Workout?

    @State private var showingNewBlock = false
    @State private var editingBlock: Block?
    @State private var blockToDelete: Block?
    @State private var blockToComplete: Block?

    @State private var showingBlockHistory = false

    // MARK: - Grouped Workouts

    private var workoutsByMonth: [(key: Date, value: [Workout])] {

        let grouped = Dictionary(
            grouping: workoutsVM.sortedWorkouts
        ) { workout in

            Calendar.current.date(
                from: Calendar.current.dateComponents(
                    [.year, .month],
                    from: workout.date
                )
            ) ?? workout.date
        }

        return grouped
            .sorted { $0.key > $1.key }
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
                        spacing: Theme.Space.lg
                    ) {

                        blocksSection

                        workoutsSection
                    }
                    .padding(.vertical, Theme.Space.sm)
                }
            }
        }
        .navigationTitle("Training")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {

            ToolbarItem(placement: .topBarTrailing) {

                Button {
                    showingNewWorkout = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(item: $selectedBlock) {
            BlockDetailView(block: $0)
        }
        .navigationDestination(isPresented: $showingBlockHistory) {
            CompletedBlocksView(blocksVM: blocksVM)
        }
        .fullScreenCover(item: $editingWorkout) {

            WorkoutFormView(
                workout: $0,
                onSave: {
                    editingWorkout = nil
                    Task { await workoutsVM.load() }
                },
                onCancel: {
                    editingWorkout = nil
                }
            )
        }
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
        .sheet(isPresented: $showingNewBlock) {

            BlockFormView(
                blocksVM: blocksVM,
                onSave: { name, startDate, type, durationWeeks, notes, colorIndex in

                    Task {

                        await blocksVM.saveBlock(
                            id: nil,
                            name: name,
                            startDate: startDate,
                            type: type,
                            durationWeeks: durationWeeks,
                            notes: notes,
                            colorIndex: colorIndex
                        )

                        showingNewBlock = false
                    }
                },
                onCancel: {
                    showingNewBlock = false
                }
            )
        }
        .sheet(item: $editingBlock) { block in
            BlockFormView(
                block: block,
                blocksVM: blocksVM,
                onSave: { name, startDate, type, durationWeeks, notes, colorIndex in

                    Task {

                        await blocksVM.saveBlock(
                            id: block.id,
                            name: name,
                            startDate: startDate,
                            type: type,
                            durationWeeks: durationWeeks,
                            notes: notes,
                            colorIndex: colorIndex
                        )

                        editingBlock = nil
                    }
                },
                onCancel: {
                    editingBlock = nil
                }
            )
        }
        .alert("Delete Workout?", isPresented: deleteWorkoutBinding) {

            Button("Cancel", role: .cancel) { }

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
        .alert("Delete Block?", isPresented: deleteBlockBinding) {

            Button("Cancel", role: .cancel) { }

            Button("Delete", role: .destructive) {

                if let block = blockToDelete {

                    Task {
                        await blocksVM.deleteBlock(id: block.id)
                    }
                }
            }

        } message: {

            Text("This will permanently delete this block.")
        }
        .task {

            await blocksVM.load()
            await workoutsVM.load()
        }
    }

    // MARK: - Loading State

    private var isInitialLoading: Bool {
        (blocksVM.isLoading || workoutsVM.isLoading)
        && blocksVM.blocks.isEmpty
        && workoutsVM.workouts.isEmpty
    }

    // MARK: - Blocks Section

    private var blocksSection: some View {

        VStack(
            alignment: .leading,
            spacing: Theme.Space.sm
        ) {

            HStack {

                Text("Blocks")
                    .font(Theme.Font.sectionTitle)

                Spacer()

                Menu {

                    Button {
                        showingBlockHistory = true
                    } label: {
                        Label("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    }

                    Button {
                        showingNewBlock = true
                    } label: {
                        Label("New Block", systemImage: "plus")
                    }

                } label: {

                    Image(systemName: "ellipsis")
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal)

            let activeBlocks =
                blocksVM.blocks
                .filter { $0.completedDate == nil }

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
                            onEdit: {
                                editingBlock = block
                            },
                            onComplete: {
                                blockToComplete = block
                            },
                            onDelete: {
                                blockToDelete = block
                            }
                        )
                        .onTapGesture {
                            selectedBlock = block
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, Theme.Space.md)
    }

    private var emptyBlocksState: some View {

        VStack(
            spacing: Theme.Space.sm
        ) {

            Text("No active blocks")
                .font(Theme.Font.cardSecondary)
                .foregroundColor(.secondary)

            Button("Add Block") {
                showingNewBlock = true
            }
            .font(Theme.Font.cardCaption)
        }
    }

    // MARK: - Workouts Section

    private var workoutsSection: some View {

        VStack(
            alignment: .leading,
            spacing: Theme.Space.md
        ) {

            if workoutsVM.workouts.isEmpty {

                emptyWorkoutsState

            } else {

                LazyVStack(
                    alignment: .leading,
                    spacing: Theme.Space.lg
                ) {

                    ForEach(workoutsByMonth, id: \.key) { monthGroup in

                        monthSection(monthGroup)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func monthSection(
        _ group: (key: Date, value: [Workout])
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: Theme.Space.md
        ) {

            Text(monthTitle(group.key))
                .font(Theme.Font.sectionTitle)
                .padding(.bottom, Theme.Space.xs)

            LazyVStack(
                spacing: Theme.Space.sm
            ) {

                ForEach(group.value) { workout in

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
        }
    }

    private var emptyWorkoutsState: some View {

        VStack(spacing: Theme.Space.md) {

            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: Theme.IconSize.xl))
                .foregroundColor(.secondary)

            Text("No workouts yet")
                .font(Theme.Font.emptyStateTitle)

            Text("Log your first workout to get started.")
                .font(Theme.Font.emptyStateDescription)
                .foregroundColor(.secondary)

            Button("Add Workout") {
                showingNewWorkout = true
            }
            .font(Theme.Font.buttonPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.xl)
    }

    // MARK: - Helpers

    private func monthTitle(_ date: Date) -> String {

        date.formatted(
            .dateTime
                .month(.abbreviated)
                .year()
        )
    }

    private var deleteWorkoutBinding: Binding<Bool> {

        Binding(
            get: { workoutToDelete != nil },
            set: { if !$0 { workoutToDelete = nil } }
        )
    }

    private var deleteBlockBinding: Binding<Bool> {

        Binding(
            get: { blockToDelete != nil },
            set: { if !$0 { blockToDelete = nil } }
        )
    }
}
