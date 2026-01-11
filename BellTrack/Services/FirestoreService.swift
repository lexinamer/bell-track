import Foundation
import FirebaseFirestore

final class FirestoreService {
    private let db = Firestore.firestore()

    private var blocksRef: CollectionReference { db.collection("blocks") }
    private var sessionsRef: CollectionReference { db.collection("sessions") }

    // MARK: - Blocks

    func fetchBlocks(userId: String) async throws -> [Block] {
        let snapshot = try await blocksRef
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        let blocks = snapshot.documents.compactMap(Block.init(from:))
        return blocks.sorted { $0.startDate > $1.startDate }
    }

    /// Creates or updates.
    func saveBlock(userId: String, block: Block) async throws {
        var block = block
        block.userId = userId

        let data = block.firestoreData

        if let id = block.id {
            try await blocksRef.document(id).setData(data, merge: true)
        } else {
            _ = try await blocksRef.addDocument(data: data)
        }
    }

    /// v1: Prefer cascade delete sessions.
    func deleteBlock(userId: String, blockId: String) async throws {
        // Delete block doc
        try await blocksRef.document(blockId).delete()

        // Delete sessions for that block (and user)
        let snapshot = try await sessionsRef
            .whereField("userId", isEqualTo: userId)
            .whereField("blockId", isEqualTo: blockId)
            .getDocuments()

        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
    }

    // MARK: - Sessions

    func fetchSessions(userId: String, blockId: String) async throws -> [Session] {
        let snapshot = try await sessionsRef
            .whereField("userId", isEqualTo: userId)
            .whereField("blockId", isEqualTo: blockId)
            .getDocuments()

        let sessions = snapshot.documents.compactMap(Session.init(from:))
        return sessions.sorted { $0.date > $1.date }
    }

    /// Creates or updates.
    func saveSession(userId: String, session: Session) async throws {
        var session = session
        session.userId = userId

        let data = session.firestoreData

        if let id = session.id {
            try await sessionsRef.document(id).setData(data, merge: true)
        } else {
            _ = try await sessionsRef.addDocument(data: data)
        }
    }

    func deleteSession(userId: String, sessionId: String) async throws {
        // If you want to enforce ownership, you can read+verify first.
        // For v1 simplicity, delete directly:
        try await sessionsRef.document(sessionId).delete()
    }
}
