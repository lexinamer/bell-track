import SwiftUI
import Combine

@MainActor
final class ExercisesViewModel: ObservableObject {

    @Published var exercises: [Exercise] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let firestore = FirestoreService()

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            exercises = try await firestore.fetchExercises()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to load exercises:", error)
        }
    }

    // MARK: - Create / Update

    func saveExercise(id: String? = nil, name: String) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        do {
            try await firestore.saveExercise(id: id, name: name)
            await load()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to save exercise:", error)
        }
    }

    // MARK: - Delete

    func deleteExercise(id: String) async {
        do {
            try await firestore.deleteExercise(id: id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to delete exercise:", error)
        }
    }
}
