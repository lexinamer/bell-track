import SwiftUI
import Combine

@MainActor
final class BlocksViewModel: ObservableObject {

    @Published var blocks: [Block] = []
    @Published var workouts: [Workout] = []
    @Published var workoutCounts: [String: Int] = [:]

    private let firestore = FirestoreService()

    // MARK: - Load

    func load() async {
        do {
            blocks = try await firestore.fetchBlocks()
            workouts = try await firestore.fetchWorkouts()
            await loadWorkoutCounts()
        } catch {
            print("❌ Failed to load blocks:", error)
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

    func saveBlock(
        id: String?,
        name: String,
        startDate: Date,
        type: BlockType,
        durationWeeks: Int?,
        notes: String? = nil
    ) async {
        
        do {
            try await firestore.saveBlock(
                id: id,
                name: name,
                startDate: startDate,
                type: type,
                durationWeeks: durationWeeks,
                notes: notes
            )
            await load()
        } catch {
            print("❌ Failed to save block:", error)
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
