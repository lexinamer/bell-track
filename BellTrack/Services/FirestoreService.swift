import Foundation
import FirebaseFirestore

final class FirestoreService {
    private let db = Firestore.firestore()

    // MARK: - References

    private func userRef(_ userId: String) -> DocumentReference {
        db.collection("users").document(userId)
    }

    private func blocksRef(userId: String) -> CollectionReference {
        userRef(userId).collection("blocks")
    }

    private func sessionsRef(userId: String, blockId: String) -> CollectionReference {
        blocksRef(userId: userId)
            .document(blockId)
            .collection("sessions")
    }

    // MARK: - Blocks

    func fetchBlocks(userId: String) async throws -> [Block] {
        let snapshot = try await blocksRef(userId: userId)
            .order(by: "startDate", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap(Block.init(from:))
    }

    func saveBlock(userId: String, block: Block) async throws {
        var block = block
        block.userId = userId

        let data = block.firestoreData

        if let id = block.id {
            try await blocksRef(userId: userId)
                .document(id)
                .setData(data, merge: true)
        } else {
            _ = try await blocksRef(userId: userId)
                .addDocument(data: data)
        }
    }

    func deleteBlock(userId: String, blockId: String) async throws {
        let blockRef = blocksRef(userId: userId).document(blockId)

        // delete sessions
        let sessionsSnapshot = try await blockRef
            .collection("sessions")
            .getDocuments()

        let batch = db.batch()
        for doc in sessionsSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }

        batch.deleteDocument(blockRef)
        try await batch.commit()
    }

    // MARK: - Sessions

    func fetchSessions(userId: String, blockId: String) async throws -> [Session] {
        let snapshot = try await sessionsRef(userId: userId, blockId: blockId)
            .order(by: "date", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap(Session.init(from:))
    }

    func fetchRecentSessions(
        userId: String,
        blockId: String,
        limit: Int = 3
    ) async throws -> [Session] {
        let snapshot = try await sessionsRef(userId: userId, blockId: blockId)
            .order(by: "date", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap(Session.init(from:))
    }

    func saveSession(userId: String, session: Session) async throws {
        let data = session.firestoreData

        if let id = session.id {
            try await sessionsRef(userId: userId, blockId: session.blockId)
                .document(id)
                .setData(data, merge: true)
        } else {
            _ = try await sessionsRef(userId: userId, blockId: session.blockId)
                .addDocument(data: data)
        }
    }

    func deleteSession(
        userId: String,
        blockId: String,
        sessionId: String
    ) async throws {
        try await sessionsRef(userId: userId, blockId: blockId)
            .document(sessionId)
            .delete()
    }
}
