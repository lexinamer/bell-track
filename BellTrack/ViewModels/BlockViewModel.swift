import SwiftUI

// MARK: - Block & Template Management

extension TrainViewModel {

    // MARK: - Block Queries

    var activeBlocks: [Block] {
        blocks
            .filter { $0.completedDate == nil && $0.startDate <= Date() }
            .sorted { $0.startDate > $1.startDate }
    }

    var activeBlock: Block? { activeBlocks.first }

    var plannedBlocks: [Block] {
        blocks
            .filter { $0.completedDate == nil && $0.startDate > Date() }
            .sorted { $0.startDate < $1.startDate }
    }

    var pastBlocks: [Block] {
        blocks
            .filter { $0.completedDate != nil }
            .sorted { $0.startDate > $1.startDate }
    }

    var allBlocks: [Block] {
        blocks.sorted { $0.startDate > $1.startDate }
    }

    var filteredBlocks: [Block] {
        blocks
            .filter { $0.completedDate == nil && $0.startDate <= Date() }
            .sorted { $0.startDate > $1.startDate }
    }

    // MARK: - Block CRUD

    func selectBlock(_ blockId: String?) {
        selectedBlockId = blockId
        selectedTemplateId = nil
    }

    @discardableResult
    func saveBlock(
        id: String?,
        name: String,
        goal: String = "",
        startDate: Date,
        endDate: Date? = nil
    ) async -> String? {
        do {
            let blockId = try await firestore.saveBlock(
                id: id,
                name: name,
                goal: goal.isEmpty ? nil : goal,
                startDate: startDate,
                endDate: endDate,
                notes: nil
            )
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

    // MARK: - Template Queries

    func templatesForBlock(_ blockId: String) -> [WorkoutTemplate] {
        templates.filter { $0.blockId == blockId }
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

    // MARK: - Template CRUD

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

    // MARK: - Template Volume Stats

    func templateVolumeStats(templateId: String) -> (best: Int, last: Int)? {
        guard let blockId = selectedBlockId else { return nil }
        guard let template = templates.first(where: { $0.id == templateId }) else { return nil }

        let templateWorkouts = workouts
            .filter { $0.blockId == blockId && $0.name == template.name }
            .sorted { $0.date > $1.date }

        guard !templateWorkouts.isEmpty else { return nil }

        let volumes = templateWorkouts.map { workout in
            workout.logs.reduce(0.0) { total, log in
                let sets = Double(log.sets ?? 0)
                let reps = Double(log.reps ?? "0") ?? 0
                let baseWeight = Double(log.weight ?? "0") ?? 0
                let weight = log.isDouble ? baseWeight * 2 : baseWeight
                let mode = exerciseMap[log.exerciseId]?.mode ?? .reps
                return (weight > 0 && reps > 0 && mode != .time)
                    ? total + (sets * reps * weight)
                    : total
            }
        }

        return (best: Int(volumes.max() ?? 0), last: Int(volumes.first ?? 0))
    }

    // MARK: - Display Helpers

    func weekProgress(for block: Block) -> String {
        guard let endDate = block.endDate else { return "Ongoing" }
        let cal = Calendar.current
        let total = cal.dateComponents([.weekOfYear], from: block.startDate, to: endDate).weekOfYear ?? 0
        let current = min(
            cal.dateComponents([.weekOfYear], from: block.startDate, to: Date()).weekOfYear ?? 0,
            total
        ) + 1
        return "Week \(current) of \(total)"
    }

    func formattedEndDate(for block: Block) -> String {
        guard let endDate = block.endDate else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: endDate)
    }

    func formattedStartDate(for block: Block) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: block.startDate)
    }

    func dateRange(for block: Block) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        let start = f.string(from: block.startDate)
        let end = f.string(from: block.completedDate ?? block.endDate ?? block.startDate)
        return "\(start) – \(end)"
    }

    func blockIndex(for blockId: String) -> Int {
        if let block = blocks.first(where: { $0.id == blockId }),
           let colorIndex = block.colorIndex {
            return colorIndex
        }
        let allSorted = (activeBlocks + pastBlocks).sorted { $0.startDate < $1.startDate }
        return allSorted.firstIndex(where: { $0.id == blockId }) ?? 0
    }

    // MARK: - Muscle Balance

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
        if lowerScore > upperScore * 2.0 { return "lower body" }
        if upperScore > lowerScore * 2.0 { return "upper body" }
        return "full body"
    }
}

// MARK: - Supporting Types

enum MuscleCategory: String, CaseIterable {
    case upper = "Upper"
    case lower = "Lower"
    case core  = "Core"

    var muscles: [MuscleGroup] {
        switch self {
        case .upper: return [.chest, .back, .shoulders, .triceps, .biceps, .forearms]
        case .lower: return [.quads, .hamstrings, .glutes, .calves]
        case .core:  return [.core]
        }
    }
}

struct MuscleBalanceData: Identifiable {
    let id = UUID()
    let category: MuscleCategory
    let score: Double
}
