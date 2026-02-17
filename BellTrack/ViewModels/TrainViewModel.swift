import SwiftUI
import Combine

enum MuscleCategory: String, CaseIterable {
    case upper = "Upper"
    case lower = "Lower"
    case core = "Core"

    var muscles: [MuscleGroup] {
        switch self {
        case .upper:
            return [.chest, .back, .shoulders, .triceps, .biceps, .forearms]
        case .lower:
            return [.quads, .hamstrings, .glutes, .calves]
        case .core:
            return [.core]
        }
    }
}

struct MuscleBalanceData: Identifiable {
    let id = UUID()
    let category: MuscleCategory
    let score: Double
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
    @Published var muscleBalance: [MuscleBalanceData] = []

    // Filter
    @Published var selectedBlockId: String?
    @Published var selectedTemplateId: String?

    private let firestore = FirestoreService.shared
    private var exerciseMap: [String: Exercise] = [:]

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

            // Build exercise map once
            exerciseMap = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })

            await autoCompleteExpiredBlocks()

            // Set default selected block to current block if not already set
            if selectedBlockId == nil {
                selectedBlockId = activeBlock?.id
            }

            // Compute stats in background
            Task {
                computeMuscleBalance()
            }
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

    // MARK: - Active Blocks

    var activeBlocks: [Block] {
        blocks
            .filter {
                $0.completedDate == nil &&
                $0.startDate <= Date()
            }
            .sorted { $0.startDate > $1.startDate }
    }

    var activeBlock: Block? {
        activeBlocks.first
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

    var allActiveTemplates: [WorkoutTemplate] {
        let activeBlockIds = Set(activeBlocks.map { $0.id })
        return templates
            .filter { activeBlockIds.contains($0.blockId) }
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
                let baseWeight = Double(log.weight ?? "0") ?? 0
                let weight = log.isDouble ? baseWeight * 2 : baseWeight

                // Look up exercise mode from exercise map
                let exercise = exerciseMap[log.exerciseId]
                let mode = exercise?.mode ?? .reps

                // Only count rep-based weighted exercises for real volume
                // Exclude time-based exercises (they skew the metric)
                if weight > 0 && reps > 0 && mode != .time {
                    return logTotal + (sets * reps * weight)
                } else {
                    return logTotal
                }
            }
        }
    }

    // MARK: - Insights

    func groupedWorkoutsByMonth(_ workouts: [Workout]) -> [(month: String, workouts: [Workout])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"

        let grouped = Dictionary(grouping: workouts) { workout in
            formatter.string(from: workout.date)
        }

        return grouped
            .map { (month: $0.key, workouts: $0.value.sorted { $0.date > $1.date }) }
            .sorted { first, second in
                guard let date1 = formatter.date(from: first.month),
                      let date2 = formatter.date(from: second.month) else {
                    return first.month > second.month
                }
                return date1 > date2
            }
    }

    var allBlocks: [Block] {
        blocks.sorted { $0.startDate > $1.startDate }
    }

    var pastBlocks: [Block] {
        blocks
            .filter { $0.completedDate != nil }
            .sorted { $0.startDate > $1.startDate }
    }

    var displayWorkouts: [Workout] {
        var filtered = filteredWorkouts

        // Filter by template if selected
        if let templateId = selectedTemplateId {
            filtered = filtered.filter { $0.name == templates.first(where: { $0.id == templateId })?.name }
        }

        return filtered
    }

    func selectTemplate(_ templateId: String?) {
        selectedTemplateId = templateId
    }

    // MARK: - Block Management

    func selectBlock(_ blockId: String?) {
        selectedBlockId = blockId
        Task {
            computeMuscleBalance()
        }
    }

    @discardableResult
    func saveBlock(
        id: String?,
        name: String,
        startDate: Date,
        endDate: Date? = nil,
        pendingTemplates: [(name: String, entries: [TemplateEntry])] = []
    ) async -> String? {
        do {
            let blockId = try await firestore.saveBlock(
                id: id,
                name: name,
                startDate: startDate,
                endDate: endDate,
                notes: nil
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

    // MARK: - Muscle Balance Computation

    private func computeMuscleBalance() {
        guard let blockId = selectedBlockId else {
            muscleBalance = []
            return
        }

        let filteredWorkouts = workouts.filter { $0.blockId == blockId }

        // Track unique exercises to avoid counting duplicates
        var uniqueExercises = Set<String>()
        var categoryScores: [MuscleCategory: Double] = [
            .upper: 0,
            .lower: 0,
            .core: 0
        ]

        for workout in filteredWorkouts {
            for log in workout.logs {
                // Only count each unique exercise once per block
                guard !uniqueExercises.contains(log.exerciseId) else { continue }
                uniqueExercises.insert(log.exerciseId)

                guard let exercise = exerciseMap[log.exerciseId] else { continue }

                // Add scores based on primary and secondary muscles
                for category in MuscleCategory.allCases {
                    // Primary muscles contribute +1.0
                    if category.muscles.contains(where: { exercise.primaryMuscles.contains($0) }) {
                        categoryScores[category, default: 0] += 1.0
                    }

                    // Secondary muscles contribute +0.5
                    if category.muscles.contains(where: { exercise.secondaryMuscles.contains($0) }) {
                        categoryScores[category, default: 0] += 0.5
                    }
                }
            }
        }

        muscleBalance = MuscleCategory.allCases.map { category in
            MuscleBalanceData(
                category: category,
                score: categoryScores[category] ?? 0
            )
        }
    }

    var balanceFocusLabel: String {
        guard !muscleBalance.isEmpty else { return "Balanced" }

        let upperScore = muscleBalance.first(where: { $0.category == .upper })?.score ?? 0
        let lowerScore = muscleBalance.first(where: { $0.category == .lower })?.score ?? 0

        // Ignore core when determining Upper vs Lower dominance (core is supplemental)

        // If lowerScore > upperScore × 2.0 → "Lower Body Focus"
        if lowerScore > upperScore * 2.0 {
            return "Lower Body Focus"
        }

        // Else if upperScore > lowerScore × 2.0 → "Upper Body Focus"
        if upperScore > lowerScore * 2.0 {
            return "Upper Body Focus"
        }

        // Otherwise balanced
        return "Balanced"
    }

    // MARK: - Template Volume Stats

    func templateVolumeStats(templateId: String) -> (best: Int, last: Int)? {
        guard let blockId = selectedBlockId else { return nil }

        // Get template name
        guard let template = templates.first(where: { $0.id == templateId }) else { return nil }

        // Get all workouts for this template in the current block
        let templateWorkouts = workouts
            .filter { $0.blockId == blockId && $0.name == template.name }
            .sorted { $0.date > $1.date } // Most recent first

        guard !templateWorkouts.isEmpty else { return nil }

        // Calculate volume for each workout
        let volumes = templateWorkouts.map { workout in
            workout.logs.reduce(0.0) { total, log in
                let sets = Double(log.sets ?? 0)
                let reps = Double(log.reps ?? "0") ?? 0
                let baseWeight = Double(log.weight ?? "0") ?? 0
                let weight = log.isDouble ? baseWeight * 2 : baseWeight

                // Look up exercise mode from exercise map
                let exercise = exerciseMap[log.exerciseId]
                let mode = exercise?.mode ?? .reps

                // Only count rep-based weighted exercises for real volume
                if weight > 0 && reps > 0 && mode != .time {
                    return total + (sets * reps * weight)
                } else {
                    return total
                }
            }
        }

        let bestVolume = Int(volumes.max() ?? 0)
        let lastVolume = Int(volumes.first ?? 0)

        return (best: bestVolume, last: lastVolume)
    }

    // MARK: - Block-Specific Helpers

    func recentWorkouts(for blockId: String, limit: Int) -> [Workout] {
        return workouts
            .filter { $0.blockId == blockId }
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map { $0 }
    }

    func balanceFocusLabel(for blockId: String) -> String {
        let filteredWorkouts = workouts.filter { $0.blockId == blockId }

        var uniqueExercises = Set<String>()
        var categoryScores: [MuscleCategory: Double] = [.upper: 0, .lower: 0, .core: 0]

        for workout in filteredWorkouts {
            for log in workout.logs {
                guard !uniqueExercises.contains(log.exerciseId) else { continue }
                uniqueExercises.insert(log.exerciseId)

                guard let exercise = exerciseMap[log.exerciseId] else { continue }

                for category in MuscleCategory.allCases {
                    if category.muscles.contains(where: { exercise.primaryMuscles.contains($0) }) {
                        categoryScores[category, default: 0] += 1.0
                    }
                    if category.muscles.contains(where: { exercise.secondaryMuscles.contains($0) }) {
                        categoryScores[category, default: 0] += 0.5
                    }
                }
            }
        }

        let upperScore = categoryScores[.upper] ?? 0
        let lowerScore = categoryScores[.lower] ?? 0

        if lowerScore > upperScore * 2.0 {
            return "Lower Body Focus"
        }
        if upperScore > lowerScore * 2.0 {
            return "Upper Body Focus"
        }
        return "Balanced"
    }

}
