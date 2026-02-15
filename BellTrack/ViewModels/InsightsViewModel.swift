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
                .filter {
                    $0.completedDate == nil &&
                    $0.startDate <= Date()
                }
                .sorted { $0.startDate > $1.startDate }

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

        let filteredWorkouts: [Workout]
        if let blockId = selectedBlockId {
            filteredWorkouts = workouts.filter { $0.blockId == blockId }
        } else {
            let activeBlockIds = Set(blocks.map(\.id))
            filteredWorkouts = workouts.filter {
                guard let blockId = $0.blockId else { return false }
                return activeBlockIds.contains(blockId)
            }
        }

        var primarySets: [MuscleGroup: Int] = [:]
        var secondarySets: [MuscleGroup: Int] = [:]

        for workout in filteredWorkouts {
            for log in workout.logs {
                let sets = log.sets ?? 0

                guard let exercise = exerciseMap[log.exerciseId] else {
                    continue
                }

                for muscle in exercise.primaryMuscles {
                    primarySets[muscle, default: 0] += sets
                }

                for muscle in exercise.secondaryMuscles {
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
