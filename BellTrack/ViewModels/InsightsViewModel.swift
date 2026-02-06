import SwiftUI
import Combine

struct MusclePercentStat: Identifiable {
    let id = UUID()
    let muscle: MuscleGroup
    let percent: Double
}

@MainActor
final class InsightsViewModel: ObservableObject {

    @Published var primaryStats: [MusclePercentStat] = []
    @Published var secondaryStats: [MusclePercentStat] = []
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

    // MARK: - Block Selection

    func selectBlock(_ blockId: String?) {
        selectedBlockId = blockId
        computeStats()
    }

    // MARK: - Compute Stats

    private func computeStats() {
        var exerciseMap: [String: Exercise] = [:]
        for exercise in exercises {
            exerciseMap[exercise.id] = exercise
        }

        let filteredWorkouts: [Workout]
        if let blockId = selectedBlockId {
            filteredWorkouts = workouts.filter { $0.blockId == blockId }
        } else {
            filteredWorkouts = workouts
        }

        var primarySets: [MuscleGroup: Int] = [:]
        var secondarySets: [MuscleGroup: Int] = [:]

        for workout in filteredWorkouts {
            for log in workout.logs {
                guard let exercise = exerciseMap[log.exerciseId] else { continue }
                let sets = log.sets ?? 0

                for muscle in exercise.primaryMuscles {
                    primarySets[muscle, default: 0] += sets
                }

                for muscle in exercise.secondaryMuscles {
                    secondarySets[muscle, default: 0] += sets
                }
            }
        }

        let totalPrimary = primarySets.values.reduce(0, +)
        let totalSecondary = secondarySets.values.reduce(0, +)

        primaryStats = MuscleGroup.allCases
            .map { muscle in
                MusclePercentStat(
                    muscle: muscle,
                    percent: totalPrimary > 0
                        ? Double(primarySets[muscle] ?? 0) / Double(totalPrimary)
                        : 0
                )
            }
            .sorted { $0.percent > $1.percent }

        secondaryStats = MuscleGroup.allCases
            .map { muscle in
                MusclePercentStat(
                    muscle: muscle,
                    percent: totalSecondary > 0
                        ? Double(secondarySets[muscle] ?? 0) / Double(totalSecondary)
                        : 0
                )
            }
            .sorted { $0.percent > $1.percent }
    }
}
