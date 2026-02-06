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
            Color.brand.background.ignoresSafeArea()

            // Content
            if (blocksVM.isLoading && workoutsVM.isLoading) && blocksVM.blocks.isEmpty && workoutsVM.workouts.isEmpty {
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
                    .padding(.vertical, 6)
                    .padding(.bottom, 80) // Space for FAB
                }
            }

            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showingNewWorkout = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.brand.primary)
                            .clipShape(Circle())
                            .shadow(color: Color.brand.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Training")
        .navigationBarTitleDisplayMode(.large)
        
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
            // Header with more breathing room
            HStack {
                Text("Blocks")
                    .font(Theme.Font.cardTitle)
                
                Spacer()
                
                Button {
//                    add historyviewhere...
                } label: {
                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .foregroundColor(Color.textSecondary)
                }
                
                Button {
                    showingNewBlock = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(Color.textSecondary)
                }
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
        }
    }

    // MARK: - Block Card

    private func blockCard(_ block: Block) -> some View {
        let isExpanded = expandedBlockId == block.id
        let blockColor = ColorTheme.blockColor(for: block.colorIndex)
        let count = blocksVM.workoutCounts[block.id] ?? 0
        let shadowColor: Color = isExpanded ? blockColor.opacity(0.6) : Color.black.opacity(0.1)
        let shadowRadius: CGFloat = isExpanded ? 10 : 2
        let shadowY: CGFloat = isExpanded ? 5 : 1

        return VStack(alignment: .leading, spacing: 6) {
            // Name
            Text(block.name)
                .font(Theme.Font.cardTitle)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)

            // Progress text
            Text(progressText(block))
                .font(Theme.Font.cardCaption)
                .foregroundColor(.white)

            // Workout count
            Text("\(count) workouts")
                .font(Theme.Font.cardCaption)
                .foregroundColor(.white)

            // Expanded: show notes at bottom
            if isExpanded, let notes = block.notes, !notes.isEmpty {
                Text("Notes: \(notes)")
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(.white)
                    .padding(.top, Theme.Space.xs)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            ZStack {
                blockColor
                if isExpanded {
                    Color.black.opacity(0.15)
                }
            }
        )
        .cornerRadius(12)
        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
        .onTapGesture {
            withAnimation {
                if expandedBlockId == block.id {
                    expandedBlockId = nil
                    filterBlockId = nil
                } else {
                    expandedBlockId = block.id
                    filterBlockId = block.id
                }
            }
        }
        .contextMenu {
            Button {
                editingBlock = block
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            if block.completedDate == nil {
                Button {
                    blockToComplete = block
                } label: {
                    Label("Complete", systemImage: "checkmark")
                }
            }
            Button(role: .destructive) {
                blockToDelete = block
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Workouts Section Header

    private var workoutsSectionHeader: some View {
        HStack {
            Text("Workouts")
                .font(Theme.Font.cardTitle)

            // Show which block is filtering (if any)
            if let blockId = filterBlockId,
               let block = blocksVM.blocks.first(where: { $0.id == blockId }) {
                Text("• \(block.name)")
                    .font(Theme.Font.cardSecondary)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.top, Theme.Space.sm)
    }

    // MARK: - Block Progress Text

    private func progressText(_ block: Block) -> String {
        switch block.type {
        case .ongoing:
            let weeksSinceStart = Calendar.current.dateComponents([.weekOfYear], from: block.startDate, to: Date()).weekOfYear ?? 0
            return "Week \(max(1, weeksSinceStart + 1)) (ongoing)"
        case .duration:
            if let weeks = block.durationWeeks {
                let weeksSinceStart = Calendar.current.dateComponents([.weekOfYear], from: block.startDate, to: Date()).weekOfYear ?? 0
                let currentWeek = min(max(1, weeksSinceStart + 1), weeks)
                return "Week \(currentWeek) of \(weeks)"
            } else {
                return ""
            }
        }
    }

    // MARK: - Workout Card

    private func workoutCard(_ workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main card content
            HStack(alignment: .top, spacing: Theme.Space.md) {
                // Date box
                VStack(spacing: 2) {
                    Text(workout.date.formatted(.dateTime.day(.defaultDigits)))
                        .font(Theme.Font.navigationTitle)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Text(workout.date.formatted(.dateTime.month(.abbreviated)))
                        .font(Theme.Font.cardCaption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .frame(width: 50, height: 50)
                .background(dateBadgeColor(for: workout))
                .cornerRadius(8)

                // Workout details
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text(workoutTitle(workout))
                        .font(Theme.Font.cardTitle)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack {
                        Image(systemName: "dumbbell")
                            .font(Theme.Font.cardCaption)
                            .foregroundColor(.secondary)

                        Text("\(workout.logs.count) exercises")
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(.secondary)

                        Image(systemName: "clock")
                            .font(Theme.Font.cardCaption)
                            .foregroundColor(.secondary)

                        Text("\(totalSets(for: workout)) sets")
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(expandedWorkoutIds.contains(workout.id) ? 180 : 0))
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    if expandedWorkoutIds.contains(workout.id) {
                        expandedWorkoutIds.remove(workout.id)
                    } else {
                        expandedWorkoutIds.insert(workout.id)
                    }
                }
            }

            // Expanded exercise details
            if expandedWorkoutIds.contains(workout.id) {
                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    ForEach(workout.logs, id: \.id) { log in
                        exerciseRow(log)
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.3))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .contextMenu {
            Button {
                editingWorkout = workout
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button {
                duplicateWorkout(workout)
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            Button(role: .destructive) {
                workoutToDelete = workout
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Exercise Row

    private func exerciseRow(_ log: WorkoutLog) -> some View {
        HStack {
            Text(formatExerciseDetails(log))
                .font(Theme.Font.cardSecondary)
                .foregroundColor(.primary)
            Spacer()
        }
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
