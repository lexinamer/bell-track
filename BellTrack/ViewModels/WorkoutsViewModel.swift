import SwiftUI
import Combine

@MainActor
final class WorkoutsViewModel: ObservableObject {

    @Published var workouts: [Workout] = []

    private let firestore = FirestoreService()

    // MARK: - Load

    func load() async {
        do {
            workouts = try await firestore.fetchWorkouts()
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
