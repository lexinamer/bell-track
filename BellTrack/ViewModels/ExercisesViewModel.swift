import SwiftUI
import Combine

@MainActor
final class ExercisesViewModel: ObservableObject {

    @Published var exercises: [Exercise] = []
    @Published var complexes: [Complex] = []
    @Published var resolvedComplexes: [ResolvedComplex] = []
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
            async let fetchedComplexes = firestore.fetchComplexes()

            exercises = try await fetchedExercises
            complexes = try await fetchedComplexes
            let workouts = try await fetchedWorkouts

            resolvedComplexes = complexes.map { $0.resolved(with: exercises) }
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

    // MARK: - Exercise CRUD

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

            if let exerciseId = id {
                try await firestore.updateExerciseNameInWorkouts(exerciseId: exerciseId, newName: name)
            }

            await load()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to save exercise:", error)
        }
    }

    func deleteExercise(id: String) async {
        do {
            try await firestore.deleteExercise(id: id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to delete exercise:", error)
        }
    }

    // MARK: - Complex CRUD

    func saveComplex(
        id: String? = nil,
        name: String,
        exerciseIds: [String]
    ) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
              !exerciseIds.isEmpty else { return }

        do {
            try await firestore.saveComplex(
                id: id,
                name: name,
                exerciseIds: exerciseIds
            )

            if let complexId = id {
                try await firestore.updateComplexNameInWorkouts(complexId: complexId, newName: name)
            }

            await load()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to save complex:", error)
        }
    }

    func deleteComplex(id: String) async {
        do {
            try await firestore.deleteComplex(id: id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to delete complex:", error)
        }
    }
}
