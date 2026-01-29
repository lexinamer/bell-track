import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class FirestoreService {

    static let shared = FirestoreService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Auth Helper

    private func requireUserID() throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "Auth", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "User not authenticated"
            ])
        }
        return uid
    }

    // MARK: - Blocks

    func fetchBlocks() async throws -> [Block] {
        let uid = try requireUserID()

        let snapshot = try await db
            .collection("users")
            .document(uid)
            .collection("blocks")
            .getDocuments()

        return snapshot.documents.compactMap {
            try? $0.data(as: Block.self)
        }
    }

    func saveBlock(_ block: Block) async throws {
        let uid = try requireUserID()

        try db
            .collection("users")
            .document(uid)
            .collection("blocks")
            .document(block.id)
            .setData(from: block)
    }

    func deleteBlock(blockID: String) async throws {
        let uid = try requireUserID()

        // delete workouts under this block
        let workouts = try await fetchWorkouts(for: blockID)
        for workout in workouts {
            try await deleteWorkout(workoutID: workout.id)
        }

        try await db
            .collection("users")
            .document(uid)
            .collection("blocks")
            .document(blockID)
            .delete()
    }

    // MARK: - Workouts (logged workouts)

    func fetchWorkouts() async throws -> [Workout] {
        let uid = try requireUserID()

        let snapshot = try await db
            .collection("users")
            .document(uid)
            .collection("workouts")
            .getDocuments()

        return snapshot.documents.compactMap {
            try? $0.data(as: Workout.self)
        }
    }

    func fetchWorkouts(for blockID: String) async throws -> [Workout] {
        let uid = try requireUserID()

        let snapshot = try await db
            .collection("users")
            .document(uid)
            .collection("workouts")
            .whereField("blockID", isEqualTo: blockID)
            .getDocuments()

        return snapshot.documents.compactMap {
            try? $0.data(as: Workout.self)
        }
    }

    func saveWorkout(_ workout: Workout) async throws {
        let uid = try requireUserID()

        try db
            .collection("users")
            .document(uid)
            .collection("workouts")
            .document(workout.id)
            .setData(from: workout)
    }

    func deleteWorkout(workoutID: String) async throws {
        let uid = try requireUserID()

        try await db
            .collection("users")
            .document(uid)
            .collection("workouts")
            .document(workoutID)
            .delete()
    }
}
