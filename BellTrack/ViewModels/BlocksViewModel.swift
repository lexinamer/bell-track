import SwiftUI
import Combine

@MainActor
final class BlocksViewModel: ObservableObject {

    @Published var blocks: [Block] = []
    @Published var workouts: [Workout] = []
    @Published var templates: [WorkoutTemplate] = []
    @Published var workoutCounts: [String: Int] = [:]
    @Published var isLoading = false

    private let firestore = FirestoreService()

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let fetchedBlocks = firestore.fetchBlocks()
            async let fetchedWorkouts = firestore.fetchWorkouts()
            async let fetchedTemplates = firestore.fetchWorkoutTemplates()
            blocks = try await fetchedBlocks
            workouts = try await fetchedWorkouts
            templates = try await fetchedTemplates
            await loadWorkoutCounts()
            await autoCompleteExpiredBlocks()
        } catch {
            print("❌ Failed to load blocks:", error)
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
                print("❌ Failed to auto-complete block:", error)
            }
        }
    }
    
    // MARK: - Load Workout Counts
    
    private func loadWorkoutCounts() async {
        // Use the already-fetched workouts instead of fetching again
        var counts: [String: Int] = [:]
        for workout in workouts {
            if let blockId = workout.blockId {
                counts[blockId, default: 0] += 1
            }
        }
        
        workoutCounts = counts
    }

    // MARK: - Save

    @discardableResult
    func saveBlock(
        id: String?,
        name: String,
        startDate: Date,
        endDate: Date? = nil,
        notes: String? = nil,
        colorIndex: Int? = nil,
        pendingTemplates: [(name: String, entries: [TemplateEntry])] = []
    ) async -> String? {

        do {
            let blockId = try await firestore.saveBlock(
                id: id,
                name: name,
                startDate: startDate,
                endDate: endDate,
                notes: notes,
                colorIndex: colorIndex
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
            print("❌ Failed to save block:", error)
            return nil
        }
    }

    // MARK: - Delete

    func deleteBlock(id: String) async {
        do {
            try await firestore.deleteBlock(id: id)
            await load()
        } catch {
            print("❌ Failed to delete block:", error)
        }
    }
    
    // MARK: - Templates

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
            print("❌ Failed to save template:", error)
        }
    }

    func deleteTemplate(id: String) async {
        do {
            try await firestore.deleteWorkoutTemplate(id: id)
            await load()
        } catch {
            print("❌ Failed to delete template:", error)
        }
    }

    // MARK: - Complete Block

    func completeBlock(id: String) async {
        // Find the block to complete
        guard let block = blocks.first(where: { $0.id == id }) else { return }
        
        do {
            // Update the block as completed (you'll need to add this to FirestoreService)
            try await firestore.completeBlock(id: block.id)
            await load()
        } catch {
            print("❌ Failed to complete block:", error)
        }
    }
}
