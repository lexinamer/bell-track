import Foundation
import FirebaseFirestore

final class FirestoreService {
    private let db = Firestore.firestore()

    // MARK: - References

    private func blocksRef(userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("blocks")
    }

    private func logsRef(userId: String, blockId: String) -> CollectionReference {
        blocksRef(userId: userId).document(blockId).collection("logs")
    }

    // MARK: - Blocks

    func fetchBlocks(userId: String) async throws -> [Block] {
        let snapshot = try await blocksRef(userId: userId)
            .order(by: "startDate", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap(Block.init(from:))
    }

    func fetchActiveBlock(userId: String) async throws -> Block? {
        let blocks = try await fetchBlocks(userId: userId)
        return blocks.first(where: { $0.isActive })
    }

    func saveBlock(userId: String, block: Block) async throws -> String {
        var block = block
        block.userId = userId

        let data = block.firestoreData

        if let id = block.id {
            try await blocksRef(userId: userId)
                .document(id)
                .setData(data, merge: true)
            return id
        } else {
            let docRef = try await blocksRef(userId: userId)
                .addDocument(data: data)
            return docRef.documentID
        }
    }

    func deleteBlock(userId: String, blockId: String) async throws {
        let blockRef = blocksRef(userId: userId).document(blockId)

        let logsSnapshot = try await blockRef
            .collection("logs")
            .getDocuments()

        let batch = db.batch()
        for doc in logsSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }

        batch.deleteDocument(blockRef)
        try await batch.commit()
    }

    func endBlock(userId: String, blockId: String) async throws {
        try await blocksRef(userId: userId)
            .document(blockId)
            .updateData([
                "durationWeeks": 0,
                "updatedAt": Timestamp(date: Date())
            ])
    }

    // MARK: - Logs

    func fetchLogs(userId: String, blockId: String) async throws -> [WorkoutLog] {
        let snapshot = try await logsRef(userId: userId, blockId: blockId)
            .order(by: "date", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap(WorkoutLog.init(from:))
    }

    func fetchLogsForWorkout(
        userId: String,
        blockId: String,
        workoutId: String
    ) async throws -> [WorkoutLog] {
        let snapshot = try await logsRef(userId: userId, blockId: blockId)
            .whereField("workoutId", isEqualTo: workoutId)
            .order(by: "date", descending: false)
            .getDocuments()

        return snapshot.documents.compactMap(WorkoutLog.init(from:))
    }

    func saveLog(userId: String, log: WorkoutLog) async throws {
        var log = log
        log.userId = userId

        let data = log.firestoreData

        if let id = log.id {
            try await logsRef(userId: userId, blockId: log.blockId)
                .document(id)
                .setData(data, merge: true)
        } else {
            _ = try await logsRef(userId: userId, blockId: log.blockId)
                .addDocument(data: data)
        }
    }

    func deleteLog(userId: String, blockId: String, logId: String) async throws {
        try await logsRef(userId: userId, blockId: blockId)
            .document(logId)
            .delete()
    }

    // MARK: - Progress Calculation

    func calculateProgress(
        userId: String,
        blockId: String,
        exerciseId: String
    ) async throws -> (first: String?, last: String?) {
        let logs = try await fetchLogs(userId: userId, blockId: blockId)

        let sortedByDate = logs.sorted { $0.date < $1.date }

        var firstValue: String?
        var lastValue: String?

        for log in sortedByDate {
            if let result = log.exerciseResults.first(where: { $0.exerciseId == exerciseId }),
               result.hasValue {
                if firstValue == nil {
                    firstValue = result.value
                }
                lastValue = result.value
            }
        }

        return (firstValue, lastValue)
    }
}
