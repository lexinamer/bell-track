import SwiftUI
import Combine

struct MusclePercentStat: Identifiable {
    let id = UUID()
    let muscle: MuscleGroup
    let percent: Double
}

@MainActor
final class TrainViewModel: ObservableObject {

    // MARK: - Published State

    @Published var blocks: [Block] = []
    @Published var workouts: [Workout] = []
    @Published var templates: [WorkoutTemplate] = []
    @Published var exercises: [Exercise] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Insights
    @Published var primaryStats: [MusclePercentStat] = []
    @Published var secondaryStats: [MusclePercentStat] = []
    @Published var balanceScore: Int = 0

    // Filter
    @Published var selectedBlockId: String?

    private let firestore = FirestoreService.shared

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let fetchedBlocks = firestore.fetchBlocks()
            async let fetchedWorkouts = firestore.fetchWorkouts()
            async let fetchedTemplates = firestore.fetchWorkoutTemplates()
            async let fetchedExercises = firestore.fetchExercises()

            blocks = try await fetchedBlocks
            workouts = try await fetchedWorkouts
            templates = try await fetchedTemplates
            exercises = try await fetchedExercises

            await autoCompleteExpiredBlocks()
            computeStats()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to load train data:", error)
        }
    }

    // MARK: - Auto-Complete Expired Blocks

    private func autoCompleteExpiredBlocks() async {
        let now = Date()

        for block in blocks {
            guard block.completedDate == nil,
                  let endDate = block.endDate,
                  now >= endDate
            else { continue }

            do {
                try await firestore.completeBlock(id: block.id)
                if let index = blocks.firstIndex(where: { $0.id == block.id }) {
                    blocks[index].completedDate = now
                }
            } catch {
                errorMessage = error.localizedDescription
                print("❌ Failed to auto-complete block:", error)
            }
        }
    }

    // MARK: - Active Block

    var activeBlock: Block? {
        blocks
            .filter {
                $0.completedDate == nil &&
                $0.startDate <= Date()
            }
            .sorted { $0.startDate > $1.startDate }
            .first
    }

    var activeBlockWorkouts: [Workout] {
        guard let block = activeBlock else { return [] }
        return workouts
            .filter { $0.blockId == block.id }
            .sorted { $0.date > $1.date }
    }

    var activeTemplates: [WorkoutTemplate] {
        guard let block = activeBlock else { return [] }
        return templates
            .filter { $0.blockId == block.id }
            .sorted { $0.name < $1.name }
    }

    // MARK: - Filtered Data

    var filteredWorkouts: [Workout] {
        if let blockId = selectedBlockId {
            return workouts
                .filter { $0.blockId == blockId }
                .sorted { $0.date > $1.date }
        } else {
            return workouts.sorted { $0.date > $1.date }
        }
    }

    var filteredBlocks: [Block] {
        blocks
            .filter { $0.completedDate == nil && $0.startDate <= Date() }
            .sorted { $0.startDate > $1.startDate }
    }

    // MARK: - Stats

    func totalWorkouts(for blockId: String?) -> Int {
        if let blockId = blockId {
            return workouts.filter { $0.blockId == blockId }.count
        }
        return workouts.count
    }

    func totalSets(for blockId: String?) -> Int {
        let filtered = blockId != nil
            ? workouts.filter { $0.blockId == blockId }
            : workouts

        return filtered.reduce(0) { total, workout in
            total + workout.logs.reduce(0) { subtotal, log in
                subtotal + (log.sets ?? 0)
            }
        }
    }

    func totalVolume(for blockId: String?) -> Double {
        let filtered = blockId != nil
            ? workouts.filter { $0.blockId == blockId }
            : workouts

        return filtered.reduce(0.0) { total, workout in
            total + workout.logs.reduce(0.0) { logTotal, log in
                let sets = Double(log.sets ?? 0)
                let reps = Double(log.reps ?? "0") ?? 0
                let weight = Double(log.weight ?? "0") ?? 0
                return logTotal + (sets * reps * weight)
            }
        }
    }

    // MARK: - Insights

    private func computeStats() {
        var exerciseMap: [String: Exercise] = [:]
        for exercise in exercises {
            exerciseMap[exercise.id] = exercise
        }

        // Filter workouts for active blocks only
        let activeBlockIds = Set(filteredBlocks.map(\.id))
        let filteredWorkouts = workouts.filter {
            guard let blockId = $0.blockId else { return false }
            return activeBlockIds.contains(blockId)
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
            .filter { $0.percent > 0 }
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
            .filter { $0.percent > 0 }
            .sorted { $0.percent > $1.percent }

        // Calculate balance score (0-100)
        balanceScore = calculateBalanceScore(
            primarySets: primarySets,
            secondarySets: secondarySets
        )
    }

    private func calculateBalanceScore(
        primarySets: [MuscleGroup: Int],
        secondarySets: [MuscleGroup: Int]
    ) -> Int {
        // Simple balance score: lower variance = better balance
        // Calculate coefficient of variation for primary muscles
        let primaryValues = Array(primarySets.values.map { Double($0) })
        guard !primaryValues.isEmpty else { return 100 }

        let mean = primaryValues.reduce(0, +) / Double(primaryValues.count)
        guard mean > 0 else { return 100 }

        let variance = primaryValues.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(primaryValues.count)
        let stdDev = sqrt(variance)
        let cv = stdDev / mean

        // Convert CV to 0-100 score (lower CV = higher score)
        // CV of 0 = perfect balance (100), CV of 1.0 = poor balance (0)
        let score = max(0, min(100, Int((1.0 - cv) * 100)))
        return score
    }

    var topThreeMuscles: [MusclePercentStat] {
        let primaryMuscles = Set(primaryStats.map(\.muscle))
        let secondaryMuscles = Set(secondaryStats.map(\.muscle))
        let allMuscles = primaryMuscles.union(secondaryMuscles)

        let combined = allMuscles.compactMap { muscle -> MusclePercentStat? in
            let p = primaryStats.first { $0.muscle == muscle }?.percent ?? 0
            let s = secondaryStats.first { $0.muscle == muscle }?.percent ?? 0

            let primaryValue = p * 0.7
            let secondaryValue = s * 0.3
            let total = primaryValue + secondaryValue

            guard total > 0 else { return nil }

            return MusclePercentStat(
                muscle: muscle,
                percent: total
            )
        }

        let sorted = combined.sorted { $0.percent > $1.percent }
        return Array(sorted.prefix(3))
    }

    var balanceScoreColor: Color {
        switch balanceScore {
        case 80...100:
            return .green
        case 60..<80:
            return .yellow
        default:
            return .red
        }
    }

    // MARK: - Block Management

    func selectBlock(_ blockId: String?) {
        selectedBlockId = blockId
    }

    @discardableResult
    func saveBlock(
        id: String?,
        name: String,
        startDate: Date,
        endDate: Date? = nil,
        notes: String? = nil,
        pendingTemplates: [(name: String, entries: [TemplateEntry])] = []
    ) async -> String? {
        do {
            let blockId = try await firestore.saveBlock(
                id: id,
                name: name,
                startDate: startDate,
                endDate: endDate,
                notes: notes
            )

            for template in pendingTemplates {
                try await firestore.saveWorkoutTemplate(
                    id: nil,
                    name: template.name,
                    blockId: blockId,
                    entries: template.entries
                )
            }

            await load()
            return blockId
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to save block:", error)
            return nil
        }
    }

    func deleteBlock(id: String) async {
        do {
            try await firestore.deleteBlock(id: id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to delete block:", error)
        }
    }

    func completeBlock(id: String) async {
        do {
            try await firestore.completeBlock(id: id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to complete block:", error)
        }
    }

    // MARK: - Template Management

    func templatesForBlock(_ blockId: String) -> [WorkoutTemplate] {
        templates.filter { $0.blockId == blockId }
    }

    func saveTemplate(
        id: String?,
        name: String,
        blockId: String,
        entries: [TemplateEntry]
    ) async {
        do {
            try await firestore.saveWorkoutTemplate(
                id: id,
                name: name,
                blockId: blockId,
                entries: entries
            )
            await load()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to save template:", error)
        }
    }

    func deleteTemplate(id: String) async {
        do {
            try await firestore.deleteWorkoutTemplate(id: id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to delete template:", error)
        }
    }

    // MARK: - Workout Management

    func saveWorkout(_ workout: Workout) async {
        do {
            try await firestore.saveWorkout(
                id: workout.id,
                name: workout.name,
                date: workout.date,
                blockId: workout.blockId,
                logs: workout.logs
            )
            await load()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to save workout:", error)
        }
    }

    func deleteWorkout(id: String) async {
        do {
            try await firestore.deleteWorkout(id: id)
            workouts.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to delete workout:", error)
        }
    }
}
