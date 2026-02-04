import SwiftUI
import Combine

@MainActor
final class ExercisesViewModel: ObservableObject {

    @Published var exercises: [Exercise] = []
    @Published var workoutCounts: [String: Int] = [:]
    @Published var setCounts: [String: Int] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let firestore = FirestoreService()

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            exercises = try await firestore.fetchExercises()
            await loadExerciseStats()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to load exercises:", error)
        }
    }

    // MARK: - Exercise Statistics

    private func loadExerciseStats() async {
        do {
            let workouts = try await firestore.fetchWorkouts()
            
            // Calculate stats for each exercise
            var workoutCountsDict: [String: Set<String>] = [:] // exercise ID → set of workout IDs
            var setCountsDict: [String: Int] = [:] // exercise ID → total sets
            
            for workout in workouts {
                for log in workout.logs {
                    let exerciseId = log.exerciseId
                    
                    // Count unique workouts per exercise
                    if workoutCountsDict[exerciseId] == nil {
                        workoutCountsDict[exerciseId] = Set<String>()
                    }
                    workoutCountsDict[exerciseId]?.insert(workout.id)
                    
                    // Sum total sets per exercise
                    let sets = log.sets ?? 0
                    setCountsDict[exerciseId, default: 0] += sets
                }
            }
            
            // Convert to final format
            workoutCounts = workoutCountsDict.mapValues { $0.count }
            setCounts = setCountsDict
            
        } catch {
            print("❌ Failed to load exercise stats:", error)
        }
    }

    // MARK: - Create / Update

    func saveExercise(id: String? = nil, name: String) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        do {
            try await firestore.saveExercise(id: id, name: name)
            
            // If this is an edit (has ID), update all workout logs with new name
            if let exerciseId = id {
                try await firestore.updateExerciseNameInWorkouts(exerciseId: exerciseId, newName: name)
            }
            
            await load()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to save exercise:", error)
        }
    }
}
