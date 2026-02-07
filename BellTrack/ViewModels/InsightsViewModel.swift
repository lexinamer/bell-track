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
    @Published var primarySetCounts: [MuscleGroup: Int] = [:]
    @Published var secondarySetCounts: [MuscleGroup: Int] = [:]
    @Published var blocks: [Block] = []
    @Published var selectedBlockId: String? = nil
    @Published var isLoading = false

    private var exercises: [Exercise] = []
    private var complexes: [Complex] = []
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
            async let fetchedComplexes = firestore.fetchComplexes()

            exercises = try await fetchedExercises
            workouts = try await fetchedWorkouts
            blocks = try await fetchedBlocks
            complexes = try await fetchedComplexes

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
        // Build exercise lookup map
        var exerciseMap: [String: Exercise] = [:]
        for exercise in exercises {
            exerciseMap[exercise.id] = exercise
        }

        // Build resolved complex muscle lookup map
        var complexMuscleMap: [String: (primary: [MuscleGroup], secondary: [MuscleGroup])] = [:]
        for complex in complexes {
            let resolved = complex.resolved(with: exercises)
            complexMuscleMap[complex.id] = (resolved.primaryMuscles, resolved.secondaryMuscles)
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
                let sets = log.sets ?? 0

                let primary: [MuscleGroup]
                let secondary: [MuscleGroup]

                if log.isComplex, let muscles = complexMuscleMap[log.exerciseId] {
                    primary = muscles.primary
                    secondary = muscles.secondary
                } else if let exercise = exerciseMap[log.exerciseId] {
                    primary = exercise.primaryMuscles
                    secondary = exercise.secondaryMuscles
                } else {
                    continue
                }

                for muscle in primary {
                    primarySets[muscle, default: 0] += sets
                }

                for muscle in secondary {
                    secondarySets[muscle, default: 0] += sets
                }
            }
        }

        primarySetCounts = primarySets
        secondarySetCounts = secondarySets

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
