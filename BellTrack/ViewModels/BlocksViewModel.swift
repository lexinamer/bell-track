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
            let blocks = try await firestore.fetchBlocks()
            self.blocks = blocks
            await loadWorkoutCounts()
        } catch {
            print("❌ Failed to load blocks:", error)
        }
    }

    // MARK: - Counts

    private func loadWorkoutCounts() async {
        do {
            let workouts = try await firestore.fetchWorkouts()
            workoutCounts = Dictionary(
                grouping: workouts.compactMap { $0.blockId },
                by: { $0 }
            ).mapValues { $0.count }
        } catch {
            print("❌ Failed to load workout counts:", error)
        }
    }

    // MARK: - Create / Update

    func saveBlock(
        id: String? = nil,
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
}
