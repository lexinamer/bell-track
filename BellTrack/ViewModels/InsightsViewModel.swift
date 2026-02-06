import SwiftUI
import Combine

@MainActor
final class InsightsViewModel: ObservableObject {

    @Published var muscleStats: [MuscleStat] = []
    @Published var blocks: [Block] = []
    @Published var selectedBlockId: String? = nil
    @Published var isLoading = false

    private var exercises: [Exercise] = []
    private var workouts: [Workout] = []
    private let firestore = FirestoreService()

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let fetchedExercises = firestore.fetchExercises()
            async let fetchedWorkouts = firestore.fetchWorkouts()
            async let fetchedBlocks = firestore.fetchBlocks()

            exercises = try await fetchedExercises
            workouts = try await fetchedWorkouts
            blocks = try await fetchedBlocks

            computeStats()
        } catch {
            print("❌ Failed to load insights:", error)
        }
    }

    // MARK: - Recompute on Block Change

    func selectBlock(_ blockId: String?) {
        selectedBlockId = blockId
        computeStats()
    }

    // MARK: - Compute Stats

    private func computeStats() {
        // Build exercise lookup
        var exerciseMap: [String: Exercise] = [:]
        for exercise in exercises {
            exerciseMap[exercise.id] = exercise
        }

        // Filter workouts by selected block
        let filtered: [Workout]
        if let blockId = selectedBlockId {
            filtered = workouts.filter { $0.blockId == blockId }
        } else {
            filtered = workouts
        }

        // Accumulate sets per muscle
        var primarySets: [MuscleGroup: Int] = [:]
        var secondarySets: [MuscleGroup: Int] = [:]
        var exerciseIds: [MuscleGroup: Set<String>] = [:]

        for workout in filtered {
            for log in workout.logs {
                guard let exercise = exerciseMap[log.exerciseId] else { continue }
                let sets = log.sets ?? 0

                for muscle in exercise.primaryMuscles {
                    primarySets[muscle, default: 0] += sets
                    exerciseIds[muscle, default: Set()].insert(exercise.id)
                }

                for muscle in exercise.secondaryMuscles {
                    secondarySets[muscle, default: 0] += sets
                    exerciseIds[muscle, default: Set()].insert(exercise.id)
                }
            }
        }

        // Build stats array
        let allMuscles = Set(primarySets.keys).union(secondarySets.keys)
        var stats: [MuscleStat] = []

        for muscle in allMuscles {
            stats.append(MuscleStat(
                muscle: muscle,
                primarySets: primarySets[muscle] ?? 0,
                secondarySets: secondarySets[muscle] ?? 0,
                exerciseCount: exerciseIds[muscle]?.count ?? 0
            ))
        }

        stats.sort { $0.totalSets > $1.totalSets }
        muscleStats = stats
    }
}
