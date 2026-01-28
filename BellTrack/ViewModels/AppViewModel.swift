import Foundation
import Combine

@MainActor
final class AppViewModel: ObservableObject {
    private let firestoreService = FirestoreService()

    @Published var activeBlock: Block?
    @Published var blocks: [Block] = []
    @Published var logs: [WorkoutLog] = []
    @Published var isLoading = false
    @Published var error: String?

    var userId: String?

    var completedBlocks: [Block] {
        blocks.filter { $0.isCompleted }
    }

    // MARK: - Block Operations

    func loadData() async {
        guard let userId else { return }

        isLoading = true
        error = nil

        do {
            blocks = try await firestoreService.fetchBlocks(userId: userId)
            activeBlock = blocks.first(where: { $0.isActive })

            if let activeBlock, let blockId = activeBlock.id {
                logs = try await firestoreService.fetchLogs(userId: userId, blockId: blockId)
            } else {
                logs = []
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func saveBlock(_ block: Block) async {
        guard let userId else { return }

        do {
            _ = try await firestoreService.saveBlock(userId: userId, block: block)
            await loadData()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func endCurrentBlock() async {
        guard let userId, let activeBlock, let blockId = activeBlock.id else { return }

        do {
            try await firestoreService.endBlock(userId: userId, blockId: blockId)
            await loadData()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteBlock(_ blockId: String) async {
        guard let userId else { return }

        do {
            try await firestoreService.deleteBlock(userId: userId, blockId: blockId)
            await loadData()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Log Operations

    func loadLogsForBlock(_ blockId: String) async {
        guard let userId else { return }

        do {
            logs = try await firestoreService.fetchLogs(userId: userId, blockId: blockId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func saveLog(_ log: WorkoutLog) async {
        guard let userId else { return }

        do {
            try await firestoreService.saveLog(userId: userId, log: log)
            await loadLogsForBlock(log.blockId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteLog(_ log: WorkoutLog) async {
        guard let userId, let logId = log.id else { return }

        do {
            try await firestoreService.deleteLog(userId: userId, blockId: log.blockId, logId: logId)
            await loadLogsForBlock(log.blockId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Progress

    func getProgress(for exerciseId: String) async -> (first: String?, last: String?) {
        guard let userId, let activeBlock, let blockId = activeBlock.id else {
            return (nil, nil)
        }

        do {
            return try await firestoreService.calculateProgress(
                userId: userId,
                blockId: blockId,
                exerciseId: exerciseId
            )
        } catch {
            return (nil, nil)
        }
    }

    func getLastLog(for workoutId: String) -> WorkoutLog? {
        logs
            .filter { $0.workoutId == workoutId }
            .sorted { $0.date > $1.date }
            .first
    }
}
