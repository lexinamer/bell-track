import SwiftUI

struct WorkoutsView: View {

    @StateObject private var vm = WorkoutsViewModel()

    @State private var editingWorkout: Workout?
    @State private var showingNewWorkout = false
    @State private var expandedWorkoutIds: Set<String> = []

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Shared header component
                PageHeader(
                    title: "Workouts",
                    buttonText: "Add Workout"
                ) {
                    showingNewWorkout = true
                }
                
                // Content
                if vm.isLoading && vm.workouts.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if vm.workouts.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    List {
                        ForEach(vm.workouts) { workout in
                            workoutCard(workout)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("Delete", role: .destructive) {
                                        Task {
                                            await vm.deleteWorkout(id: workout.id)
                                        }
                                    }
                                    .tint(.red)
                                    
                                    Button("Duplicate") {
                                        duplicateWorkout(workout)
                                    }
                                    .tint(.blue)
                                    
                                    Button("Edit") {
                                        editingWorkout = workout
                                    }
                                    .tint(.orange)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 6)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(item: $editingWorkout) { workout in
            WorkoutFormView(
                workout: workout,
                onSave: {
                    editingWorkout = nil
                    Task { await vm.load() }
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
                    Task { await vm.load() }
                },
                onCancel: {
                    showingNewWorkout = false
                }
            )
        }
        .task {
            await vm.load()
        }
    }

    // MARK: - Workout Card

    private func workoutCard(_ workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // Main card content
            HStack(alignment: .top, spacing: 16) {
                // Date box (like the reference image)
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
                VStack(alignment: .leading, spacing: 4) {
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
                
                Button {
                    if expandedWorkoutIds.contains(workout.id) {
                        expandedWorkoutIds.remove(workout.id)
                    } else {
                        expandedWorkoutIds.insert(workout.id)
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(expandedWorkoutIds.contains(workout.id) ? 180 : 0))
                }
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture {
                if expandedWorkoutIds.contains(workout.id) {
                    expandedWorkoutIds.remove(workout.id)
                } else {
                    expandedWorkoutIds.insert(workout.id)
                }
            }
            
            // Expanded exercise details
            if expandedWorkoutIds.contains(workout.id) {
                Divider()
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
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

    // MARK: - Helpers

    private func workoutTitle(_ workout: Workout) -> String {
        if let name = workout.name, !name.isEmpty {
            return name
        }
        return workout.logs.map { $0.exerciseName }.joined(separator: ", ")
    }

    private func dateBadgeColor(for workout: Workout) -> Color {
        if let blockId = workout.blockId, let colorIndex = vm.blockColors[blockId] {
            return ColorTheme.blockColor(for: colorIndex)
        } else if workout.blockId != nil {
            // Has a block but no colorIndex set yet — use default palette color
            return ColorTheme.blockColor(for: nil)
        } else {
            return ColorTheme.unassignedWorkoutColor
        }
    }

    private func totalSets(for workout: Workout) -> Int {
        workout.logs.compactMap { $0.sets }.reduce(0, +)
    }

    private func duplicateWorkout(_ workout: Workout) {
        // Create a new workout template with the same exercises but today's date
        // User can modify and save manually
        let workoutTemplate = Workout(
            id: UUID().uuidString,
            name: workout.name,
            date: Date(),
            blockId: workout.blockId,
            logs: workout.logs.map { log in
                WorkoutLog(
                    id: UUID().uuidString, // New log IDs
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
        
        // Exercise name
        components.append(log.exerciseName)
        
        // Sets and Reps
        if let sets = log.sets, sets > 0 {
            if let reps = log.reps, !reps.isEmpty {
                components.append("\(sets)x\(reps)")
            } else {
                components.append("\(sets) sets")
            }
        }
        
        // Weight (now String)
        if let weight = log.weight, !weight.isEmpty {
            components.append("\(weight)kg")
        }
        
        // Notes
        if let note = log.note, !note.isEmpty {
            components.append(note)
        }
        
        return components.joined(separator: " • ")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.plaintext")
                .font(.system(size: Theme.IconSize.xl))
                .foregroundColor(.secondary)

            Text("No workouts yet")
                .font(Theme.Font.cardTitle)

            Text("Log your first workout.")
                .font(Theme.Font.cardSecondary)
                .foregroundColor(.secondary)
        }
    }
}
