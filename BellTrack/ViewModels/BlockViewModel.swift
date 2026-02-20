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
    
    func templateVolumeDelta(templateId: String, blockId: String) -> Int? {
        guard let template = templates.first(where: { $0.id == templateId }) else { return nil }

        let sorted = workouts
            .filter { $0.blockId == blockId && $0.name == template.name }
            .sorted { $0.date > $1.date }

        guard sorted.count >= 2 else { return nil }

        let calcVolume: (Workout) -> Int = { workout in
            Int(workout.logs.reduce(0.0) { total, log in
                let sets = Double(log.sets ?? 0)
                let reps = Double(log.reps ?? "0") ?? 0
                let base = Double(log.weight ?? "0") ?? 0
                let weight = log.isDouble ? base * 2 : base
                let mode = self.exerciseMap[log.exerciseId]?.mode ?? .reps
                return (weight > 0 && reps > 0 && mode != .time) ? total + sets * reps * weight : total
            })
        }

        let last = calcVolume(sorted[0])
        let prev = calcVolume(sorted[1])
        guard last > 0 else { return nil }
        return last - prev
    }
}
