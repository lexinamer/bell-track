import SwiftUI
import Combine

@MainActor
final class BlocksViewModel: ObservableObject {

    @Published var blocks: [Block] = []
    @Published var workoutCounts: [String: Int] = [:]

    private let firestore = FirestoreService()

    // MARK: - Load

    func load() async {
        do {
            blocks = try await firestore.fetchBlocks()
            await loadWorkoutCounts()
        } catch {
            print("❌ Failed to load blocks:", error)
        }
    }
    
    // MARK: - Load Workout Counts
    
    private func loadWorkoutCounts() async {
        do {
            let workouts = try await firestore.fetchWorkouts()
            
            // Count workouts per block
            var counts: [String: Int] = [:]
            for workout in workouts {
                if let blockId = workout.blockId {
                    counts[blockId, default: 0] += 1
                }
            }
            
            workoutCounts = counts
        } catch {
            print("❌ Failed to load workout counts:", error)
        }
    }

    // MARK: - Save

    func saveBlock(
        id: String?,
        name: String,
        startDate: Date,
        type: BlockType,
        durationWeeks: Int?
    ) async {
        do {
            try await firestore.saveBlock(
                id: id,
                name: name,
                startDate: startDate,
                type: type,
                durationWeeks: durationWeeks
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
        guard let block = blocks.first(where: { $0.id == id }) else { return }
        
        do {
            try await firestore.completeBlock(id: block.id)
            await load()
        } catch {
            print("❌ Failed to complete block:", error)
        }
    }
}
