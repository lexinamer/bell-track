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
            async let fetchedExercises = firestore.fetchExercises()
            async let fetchedWorkouts = firestore.fetchWorkouts()
            exercises = try await fetchedExercises
            let workouts = try await fetchedWorkouts
            loadExerciseStats(from: workouts)
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to load exercises:", error)
        }
    }

    // MARK: - Exercise Statistics

    private func loadExerciseStats(from workouts: [Workout]) {
        var workoutCountsDict: [String: Set<String>] = [:]
        var setCountsDict: [String: Int] = [:]

        for workout in workouts {
            for log in workout.logs {
                let exerciseId = log.exerciseId
                workoutCountsDict[exerciseId, default: Set()].insert(workout.id)
                setCountsDict[exerciseId, default: 0] += (log.sets ?? 0)
            }
        }

        workoutCounts = workoutCountsDict.mapValues { $0.count }
        setCounts = setCountsDict
    }

    // MARK: - Create / Update

    func saveExercise(
        id: String? = nil,
        name: String,
        primaryMuscles: [MuscleGroup],
        secondaryMuscles: [MuscleGroup]
    ) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        do {
            try await firestore.saveExercise(
                id: id,
                name: name,
                primaryMuscles: primaryMuscles,
                secondaryMuscles: secondaryMuscles
            )
            
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
