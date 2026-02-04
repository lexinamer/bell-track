import SwiftUI

struct DetailView: View {
    let title: String
    let filterType: DetailFilterType
    let filterId: String?
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var workoutsByExercise: [String: [(date: Date, details: String, note: String?)]] = [:]
    private let firestore = FirestoreService()
    
    enum DetailFilterType {
        case block(Block)
        case exercise(Exercise)
        case allTime
    }
    
    // Convenience initializers
    init(block: Block) {
        self.title = block.name
        self.filterType = .block(block)
        self.filterId = block.id
    }
    
    init(exercise: Exercise) {
        self.title = exercise.name
        self.filterType = .exercise(exercise)
        self.filterId = exercise.id
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if workoutsByExercise.isEmpty {
                    VStack(spacing: 16) {
                        Text("No workouts found")
                            .font(Theme.Font.cardTitle)
                            .foregroundColor(.secondary)
                        
                        Text(emptyStateMessage)
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(Array(workoutsByExercise.keys.sorted()), id: \.self) { exerciseName in
                            exerciseSection(exerciseName: exerciseName, workouts: workoutsByExercise[exerciseName] ?? [])
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadWorkoutData()
        }
    }
    
    // MARK: - Empty State Message
    
    private var emptyStateMessage: String {
        switch filterType {
        case .block:
            return "Workouts need to have this block assigned to show up here."
        case .exercise:
            return "No workouts found with this exercise."
        case .allTime:
            return "No workouts found."
        }
    }
    
    // MARK: - Exercise Section
    
    private func exerciseSection(exerciseName: String, workouts: [(date: Date, details: String, note: String?)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(exerciseName)
                .font(Theme.Font.cardTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
            
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(workouts.enumerated()), id: \.offset) { _, workout in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .top, spacing: 16) {
                            // Date
                            Text(workout.date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(Theme.Font.cardSecondary)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .leading)
                            
                            // Details
                            Text(workout.details.isEmpty ? "No details" : workout.details)
                                .font(Theme.Font.cardSecondary)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 1)
                }
            }
        }
    }
    
    // MARK: - Load Data
    
    private func loadWorkoutData() async {
        do {
            let workouts = try await firestore.fetchWorkouts()
            
            // Filter workouts based on type
            let filteredWorkouts: [Workout]
            switch filterType {
            case .block(let block):
                filteredWorkouts = workouts.filter { $0.blockId == block.id }
            case .exercise(let exercise):
                filteredWorkouts = workouts.filter { workout in
                    workout.logs.contains { $0.exerciseId == exercise.id }
                }
            case .allTime:
                filteredWorkouts = workouts
            }
            
            // Group by exercise and format
            var grouped: [String: [(date: Date, details: String, note: String?)]] = [:]
            
            for workout in filteredWorkouts {
                for log in workout.logs {
                    // For exercise detail view, only show logs for that specific exercise
                    if case .exercise(let exercise) = filterType {
                        guard log.exerciseId == exercise.id else { continue }
                    }
                    
                    let exerciseName = log.exerciseName
                    let details = formatWorkoutDetails(log)
                    let note = log.note
                    
                    if grouped[exerciseName] == nil {
                        grouped[exerciseName] = []
                    }
                    grouped[exerciseName]?.append((date: workout.date, details: details, note: note))
                }
            }
            
            // Sort workouts by date within each exercise
            for exerciseName in grouped.keys {
                grouped[exerciseName]?.sort { $0.date < $1.date }
            }
            
            await MainActor.run {
                self.workoutsByExercise = grouped
            }
        } catch {
            print("❌ Failed to load workout data:", error)
        }
    }
    
    // MARK: - Format Details
    
    private func formatWorkoutDetails(_ log: WorkoutLog) -> String {
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
        
        // Weight
        if let weight = log.weight, !weight.isEmpty {
            components.append("\(weight)kg")
        }
        
        // Notes
        if let note = log.note, !note.isEmpty {
            components.append(note)
        }
        
        return components.joined(separator: " • ")
    }
}
