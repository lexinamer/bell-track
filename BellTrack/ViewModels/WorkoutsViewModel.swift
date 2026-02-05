import SwiftUI
import Combine

@MainActor
final class WorkoutsViewModel: ObservableObject {

    @Published var workouts: [Workout] = []
    @Published var blockColors: [String: Int] = [:]  // blockId -> colorIndex
    @Published var isLoading = false

    private let firestore = FirestoreService()

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let fetchedWorkouts = firestore.fetchWorkouts()
            async let fetchedBlocks = firestore.fetchBlocks()
            workouts = try await fetchedWorkouts
            let blocks = try await fetchedBlocks
            var colors: [String: Int] = [:]
            for block in blocks {
                if let colorIndex = block.colorIndex {
                    colors[block.id] = colorIndex
                }
            }
            blockColors = colors
        } catch {
            print("❌ Failed to load workouts:", error)
        }
    }

    // MARK: - Delete

    func deleteWorkout(id: String) async {
        do {
            try await firestore.deleteWorkout(id: id)
            await load()
        } catch {
            print("❌ Failed to delete workout:", error)
        }
    }
}
