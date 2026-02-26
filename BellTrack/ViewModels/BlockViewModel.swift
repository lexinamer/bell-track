import SwiftUI

// MARK: - Block & Template Management

extension TrainViewModel {
    
    // MARK: - Block Queries
    
    var activeBlocks: [Block] {
        let today = Calendar.current.startOfDay(for: Date())
        return blocks
            .filter { $0.completedDate == nil && Calendar.current.startOfDay(for: $0.startDate) <= today }
            .sorted { $0.startDate > $1.startDate }
    }

    var activeBlock: Block? { activeBlocks.first }

    var plannedBlocks: [Block] {
        let today = Calendar.current.startOfDay(for: Date())
        return blocks
            .filter { $0.completedDate == nil && Calendar.current.startOfDay(for: $0.startDate) > today }
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
        let today = Calendar.current.startOfDay(for: Date())
        return blocks
            .filter { $0.completedDate == nil && Calendar.current.startOfDay(for: $0.startDate) <= today }
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
        entries: [TemplateEntry],
        workoutType: WorkoutType = .strict,
        duration: Int? = nil
    ) async {
        do {
            // If renaming an existing template, cascade to all past workouts
            if let id = id,
               let oldName = templates.first(where: { $0.id == id })?.name,
               oldName != name {
                try await firestore.updateWorkoutNamesForTemplate(oldName: oldName, newName: name)
            }
            try await firestore.saveWorkoutTemplate(
                id: id,
                name: name,
                blockId: blockId,
                entries: entries,
                workoutType: workoutType,
                duration: duration
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
    
    // MARK: - Template Delta Stats

    func templateVolumeDelta(templateId: String, blockId: String) -> Int? {
        guard let template = templates.first(where: { $0.id == templateId }) else { return nil }

        let sorted = workouts
            .filter { $0.blockId == blockId && $0.name == template.name }
            .sorted { $0.date < $1.date }

        guard sorted.count >= 2 else { return nil }

        let calcVolume: (Workout) -> Int = { workout in
            Int(workout.logs.reduce(0.0) { total, log in
                guard let exercise = self.exercises.first(where: { $0.id == log.exerciseId }),
                      exercise.mode != .time else { return total }
                return total + log.totalVolume
            })
        }

        let latest = calcVolume(sorted.last!)
        let first = calcVolume(sorted.first!)
        guard latest > 0 else { return nil }
        return latest - first
    }

    func templateRepsDelta(templateId: String, blockId: String) -> Int? {
        guard let template = templates.first(where: { $0.id == templateId }) else { return nil }

        let sorted = workouts
            .filter { $0.blockId == blockId && $0.name == template.name }
            .sorted { $0.date < $1.date }

        guard sorted.count >= 2 else { return nil }

        let calcReps: (Workout) -> Int = { workout in
            workout.logs.reduce(0) { $0 + $1.totalReps }
        }

        let latest = calcReps(sorted.last!)
        let first = calcReps(sorted.first!)
        guard latest > 0 else { return nil }
        return latest - first
    }

    func workoutTotalReps(_ workout: Workout) -> Int {
        workout.logs.reduce(0) { $0 + $1.totalReps }
    }

    // MARK: - Display Helpers
    
    func weekProgress(for block: Block) -> String {
        let cal = Calendar.current
        let currentWeek = (cal.dateComponents([.weekOfYear], from: block.startDate, to: Date()).weekOfYear ?? 0) + 1
        guard let endDate = block.endDate else { return "Week \(currentWeek)" }
        let total = cal.dateComponents([.weekOfYear], from: block.startDate, to: endDate).weekOfYear ?? 0
        let clamped = min(currentWeek - 1, total) + 1
        return "Week \(clamped) of \(total)"
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
}
