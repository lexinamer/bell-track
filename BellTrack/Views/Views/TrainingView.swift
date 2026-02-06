import SwiftUI

struct TrainingView: View {

    @StateObject private var blocksVM = BlocksViewModel()
    @StateObject private var workoutsVM = WorkoutsViewModel()

    // Workout state
    @State private var editingWorkout: Workout?
    @State private var showingNewWorkout = false
    @State private var expandedWorkoutIds: Set<String> = []
    @State private var filterBlockId: String? = nil  // nil = All workouts
    @State private var workoutToDelete: Workout? = nil

    // Block state
    @State private var showingNewBlock = false
    @State private var expandedBlockId: String? = nil
    @State private var editingBlock: Block? = nil
    @State private var blockToDelete: Block? = nil
    @State private var blockToComplete: Block? = nil

    // Filtered workouts
    private var filteredWorkouts: [Workout] {
        if filterBlockId == "__unassigned__" {
            return workoutsVM.workouts.filter { $0.blockId == nil }
        } else if let blockId = filterBlockId {
            return workoutsVM.workouts.filter { $0.blockId == blockId }
        }
        return workoutsVM.workouts
    }

    var body: some View {
        ZStack {
            Color.brand.background
                .ignoresSafeArea()

            // Content
            if (blocksVM.isLoading && workoutsVM.isLoading)
                && blocksVM.blocks.isEmpty
                && workoutsVM.workouts.isEmpty {

                ProgressView()

            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Space.md) {

                        // Blocks section
                        blocksSection
                            .padding(.horizontal)

                        // Workouts section header
                        workoutsSectionHeader
                            .padding(.horizontal)

                        // Workout Cards
                        if filteredWorkouts.isEmpty {
                            emptyWorkoutsState
                                .padding(.horizontal)
                                .padding(.vertical, 20)
                        } else {
                            ForEach(filteredWorkouts) { workout in
                                workoutCard(workout)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical, Theme.Space.xs)
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

        
        // Workout sheets
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
        // Block sheets
        .sheet(isPresented: $showingNewBlock) {
            BlockFormView(
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
        .alert("Delete Block?", isPresented: .init(
            get: { blockToDelete != nil },
            set: { if !$0 { blockToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { blockToDelete = nil }
            Button("Delete", role: .destructive) {
                if let block = blockToDelete {
                    Task { await blocksVM.deleteBlock(id: block.id) }
                }
                blockToDelete = nil
            }
        } message: {
            Text("This will permanently delete \"\(blockToDelete?.name ?? "")\". Workouts assigned to this block will not be deleted.")
        }
        .alert("Complete Block?", isPresented: .init(
            get: { blockToComplete != nil },
            set: { if !$0 { blockToComplete = nil } }
        )) {
            Button("Cancel", role: .cancel) { blockToComplete = nil }
            Button("Complete") {
                if let block = blockToComplete {
                    Task { await blocksVM.completeBlock(id: block.id) }
                }
                blockToComplete = nil
            }
        } message: {
            Text("Mark \"\(blockToComplete?.name ?? "")\" as completed?")
        }
        .alert("Delete Workout?", isPresented: .init(
            get: { workoutToDelete != nil },
            set: { if !$0 { workoutToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { workoutToDelete = nil }
            Button("Delete", role: .destructive) {
                if let workout = workoutToDelete {
                    Task { await workoutsVM.deleteWorkout(id: workout.id) }
                }
                workoutToDelete = nil
            }
        } message: {
            Text("This will permanently delete this workout.")
        }
        .task {
            await blocksVM.load()
            await workoutsVM.load()
        }
    }

    // MARK: - Blocks Section (2-Column Grid)

    private var blocksSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            HStack {
                Text("Blocks")
                    .font(Theme.Font.sectionTitle)

                Spacer()

                Menu {
                    Button {
                        // add history view here
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
                        .foregroundColor(Color.textSecondary.opacity(0.6))
                }
                .padding(.trailing, Theme.Space.sm)
            }

            let activeBlocks = blocksVM.blocks.filter { $0.completedDate == nil }

            if activeBlocks.isEmpty {
                Text("No active blocks")
                    .font(Theme.Font.cardSecondary)
                    .foregroundColor(.secondary)
                    .padding(.vertical, Theme.Space.sm)
            } else {
                // 2-column grid of block cards
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: Theme.Space.md, alignment: .top),
                    GridItem(.flexible(), spacing: Theme.Space.md, alignment: .top)
                ], spacing: Theme.Space.md) {
                    ForEach(activeBlocks) { block in
                        blockCard(block)
                    }
                }
            }
            Divider()
                .padding(.vertical, Theme.Space.md)
        }
        .padding(.top, Theme.Space.md)
    }

    // MARK: - Block Card

    private func blockCard(_ block: Block) -> some View {
        BlockCard(
            block: block,
            workoutCount: blocksVM.workoutCounts[block.id] ?? 0,
            isExpanded: expandedBlockId == block.id,
            backgroundColor: ColorTheme.blockColor(for: block.colorIndex),

            onToggle: {
                if expandedBlockId == block.id {
                    expandedBlockId = nil
                    filterBlockId = nil
                } else {
                    expandedBlockId = block.id
                    filterBlockId = block.id
                }
            },

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
    }

    // MARK: - Workouts Section Header

    private var workoutsSectionHeader: some View {
        HStack {
            Text("Workouts")
                .font(Theme.Font.sectionTitle)

            // Show which block is filtering (if any)
            if let blockId = filterBlockId,
               let block = blocksVM.blocks.first(where: { $0.id == blockId }) {
                Text("• \(block.name)")
                    .font(Theme.Font.cardSecondary)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Workout Card

    private func workoutCard(_ workout: Workout) -> some View {
        WorkoutCard(
            workout: workout,
            isExpanded: expandedWorkoutIds.contains(workout.id),

            onToggle: {
                withAnimation {
                    if expandedWorkoutIds.contains(workout.id) {
                        expandedWorkoutIds.remove(workout.id)
                    } else {
                        expandedWorkoutIds.insert(workout.id)
                    }
                }
            },

            onEdit: {
                editingWorkout = workout
            },

            onDuplicate: {
                duplicateWorkout(workout)
            },

            onDelete: {
                workoutToDelete = workout
            },

            dateBadgeColor: dateBadgeColor(for: workout),
            title: workoutTitle(workout),
            exerciseCountText:
                "\(workout.logs.count) exercise\(workout.logs.count == 1 ? "" : "s") • \(totalSets(for: workout)) sets",
            logs: workout.logs
        )
    }


    // MARK: - Workout Helpers

    private func workoutTitle(_ workout: Workout) -> String {
        if let name = workout.name, !name.isEmpty {
            return name
        }
        return workout.logs.map { $0.exerciseName }.joined(separator: ", ")
    }

    private func dateBadgeColor(for workout: Workout) -> Color {
        if let blockId = workout.blockId, let colorIndex = workoutsVM.blockColors[blockId] {
            return ColorTheme.blockColor(for: colorIndex)
        } else if workout.blockId != nil {
            return ColorTheme.blockColor(for: nil)
        } else {
            return ColorTheme.unassignedWorkoutColor
        }
    }

    private func totalSets(for workout: Workout) -> Int {
        workout.logs.compactMap { $0.sets }.reduce(0, +)
    }

    private func duplicateWorkout(_ workout: Workout) {
        let workoutTemplate = Workout(
            id: UUID().uuidString,
            name: workout.name,
            date: Date(),
            blockId: workout.blockId,
            logs: workout.logs.map { log in
                WorkoutLog(
                    id: UUID().uuidString,
                    exerciseId: log.exerciseId,
                    exerciseName: log.exerciseName,
                    sets: log.sets,
                    reps: log.reps,
                    weight: log.weight,
                    note: log.note
                )
            }
        )
        editingWorkout = workoutTemplate
    }

    private func formatExerciseDetails(_ log: WorkoutLog) -> String {
        var components: [String] = []
        components.append(log.exerciseName)

        if let sets = log.sets, sets > 0 {
            if let reps = log.reps, !reps.isEmpty {
                components.append("\(sets)x\(reps)")
            } else {
                components.append("\(sets) sets")
            }
        }

        if let weight = log.weight, !weight.isEmpty {
            components.append("\(weight)kg")
        }

        if let note = log.note, !note.isEmpty {
            components.append(note)
        }

        return components.joined(separator: " • ")
    }

    // MARK: - Empty Workouts State

    private var emptyWorkoutsState: some View {
        VStack(spacing: Theme.Space.md) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: Theme.IconSize.xl))
                .foregroundColor(.secondary)

            if filterBlockId != nil {
                Text("No workouts in this block")
                    .font(Theme.Font.cardTitle)

                Text("Assign workouts to this block or tap the block again to show all.")
                    .font(Theme.Font.cardSecondary)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("No workouts yet")
                    .font(Theme.Font.cardTitle)

                Text("Log your first workout to get started.")
                    .font(Theme.Font.cardSecondary)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
