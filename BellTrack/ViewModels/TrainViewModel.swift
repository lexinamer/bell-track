import SwiftUI
import Combine

@MainActor
final class TrainViewModel: ObservableObject {

    // MARK: - Published State

    @Published var blocks: [Block] = []
    @Published var workouts: [Workout] = []
    @Published var templates: [WorkoutTemplate] = []
    @Published var exercises: [Exercise] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Filter
    @Published var selectedBlockId: String?
    @Published var selectedTemplateId: String?

    let firestore = FirestoreService.shared
    var exerciseMap: [String: Exercise] = [:]

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let fetchedBlocks = firestore.fetchBlocks()
            async let fetchedWorkouts = firestore.fetchWorkouts()
            async let fetchedTemplates = firestore.fetchWorkoutTemplates()
            async let fetchedExercises = firestore.fetchExercises()

            blocks = try await fetchedBlocks
            workouts = try await fetchedWorkouts
            templates = try await fetchedTemplates
            exercises = try await fetchedExercises

            exerciseMap = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })

            await autoCompleteExpiredBlocks()

            if selectedBlockId == nil {
                selectedBlockId = activeBlock?.id
            }

        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to load train data:", error)
        }
    }

    // MARK: - Auto-Complete Expired Blocks

    func autoCompleteExpiredBlocks() async {
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
                errorMessage = error.localizedDescription
                print("❌ Failed to auto-complete block:", error)
            }
        }
    }
}
