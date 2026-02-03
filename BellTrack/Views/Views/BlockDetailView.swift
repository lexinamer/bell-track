import SwiftUI

struct BlockDetailView: View {
    let block: Block
    @Environment(\.dismiss) private var dismiss
    
    @State private var workoutsByExercise: [String: [(date: Date, details: String)]] = [:]
    private let firestore = FirestoreService()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if workoutsByExercise.isEmpty {
                    VStack(spacing: 16) {
                        Text("No workouts found for this block")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Workouts need to have this block assigned to show up here.")
                            .font(.subheadline)
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
                    .padding()
                }
            }
            .navigationTitle(block.name)
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
    
    // MARK: - Exercise Section
    
    private func exerciseSection(exerciseName: String, workouts: [(date: Date, details: String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(exerciseName)
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(Array(workouts.enumerated()), id: \.offset) { _, workout in
                HStack {
                    Text(workout.date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .leading)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(workout.details)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Load Data
    
    private func loadWorkoutData() async {
        do {
            let workouts = try await firestore.fetchWorkouts()
            
            // Filter workouts for this block
            let blockWorkouts = workouts.filter { $0.blockId == block.id }
            
            // Group by exercise and format
            var grouped: [String: [(date: Date, details: String)]] = [:]
            
            for workout in blockWorkouts {
                for log in workout.logs {
                    let exerciseName = log.exerciseName
                    let details = formatWorkoutDetails(log)
                    
                    if grouped[exerciseName] == nil {
                        grouped[exerciseName] = []
                    }
                    grouped[exerciseName]?.append((date: workout.date, details: details))
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
        
        // Rounds and Reps/Time
        if let rounds = log.rounds, rounds > 0 {
            if let reps = log.reps, !reps.isEmpty {
                components.append("\(rounds)x\(reps)")
            } else if let time = log.time, !time.isEmpty {
                components.append("\(rounds)x\(time)")
            } else {
                components.append("\(rounds) sets")
            }
        }
        
        // Weight
        if let weight = log.weight, weight > 0 {
            components.append("\(Int(weight))kg")
        }
        
        return components.joined(separator: " • ")
    }
}
