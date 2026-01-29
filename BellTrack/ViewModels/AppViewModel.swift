import Foundation
import SwiftUI
import Combine   // ← THIS WAS MISSING

@MainActor
final class AppViewModel: ObservableObject {

    // MARK: - Dependencies
    private let firestore = FirestoreService()

    // MARK: - Published State
    @Published var blocks: [Block] = []
    @Published var workouts: [Workout] = []
    @Published var workoutLogs: [WorkoutLog] = []

    @Published var activeBlock: Block?
    @Published var isSaving: Bool = false

    @Published var error: AppError?
    @Published var successMessage: String?
    @Published var isLoading: Bool = false

    // MARK: - Load

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedBlocks = try await firestore.fetchBlocks()
            blocks = fetchedBlocks
            activeBlock = fetchedBlocks.first

            guard let block = activeBlock else {
                workouts = []
                workoutLogs = []
                return
            }

            let fetchedWorkouts = try await firestore.fetchWorkouts(for: block.id)
            workouts = fetchedWorkouts

            var allLogs: [WorkoutLog] = []
            for workout in fetchedWorkouts {
                let logs = try await firestore.fetchLogs(for: workout.id)
                allLogs.append(contentsOf: logs)
            }
            workoutLogs = allLogs

        } catch {
            self.error = .dataError(error.localizedDescription)
        }
    }

    // MARK: - Blocks

    func saveBlock(_ block: Block) async {
        isSaving = true
        do {
            try await firestore.saveBlock(block)
            successMessage = "Block saved"
            await loadData()
        } catch {
            self.error = .dataError(error.localizedDescription)
        }
        isSaving = false
    }

    func deleteBlock(_ blockId: String) async {
        isSaving = true
        do {
            try await firestore.deleteBlock(blockId)
            successMessage = "Block deleted"
            await loadData()
        } catch {
            self.error = .dataError(error.localizedDescription)
        }
        isSaving = false
    }

    func endCurrentBlock() async {
        guard let block = activeBlock else { return }
        await deleteBlock(block.id)
    }

    // MARK: - Workouts

    func workouts(for block: Block) -> [Workout] {
        workouts.filter { $0.blockId == block.id }
    }

    func saveWorkout(_ workout: Workout) async {
        isSaving = true
        do {
            try await firestore.saveWorkout(workout)
            successMessage = "Workout saved"
            await loadData()
        } catch {
            self.error = .dataError(error.localizedDescription)
        }
        isSaving = false
    }

    // MARK: - Logs

    func saveWorkoutLog(_ log: WorkoutLog) async {
        isSaving = true
        do {
            try await firestore.saveWorkoutLog(log)
            successMessage = "Workout logged"
            await loadData()
        } catch {
            self.error = .dataError(error.localizedDescription)
        }
        isSaving = false
    }

    // MARK: - Progress

    func getProgress(for exerciseId: String) -> (first: String?, last: String?) {
        let results = workoutLogs
            .flatMap { $0.exerciseResults }
            .filter { $0.exerciseId == exerciseId }

        let first = results.first?.values.values.first
        let last = results.last?.values.values.first

        return (first, last)
    }

    func refreshProgress() async {
        await loadData()
    }

    // MARK: - Messaging

    func clearError() {
        error = nil
    }

    func clearSuccessMessage() {
        successMessage = nil
    }
}

// MARK: - AppError

enum AppError: Error, LocalizedError {
    case dataError(String)

    var errorDescription: String? {
        switch self {
        case .dataError(let message):
            return message
        }
    }
}
