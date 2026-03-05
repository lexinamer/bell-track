import Foundation
import FirebaseFirestore
import FirebaseAuth

final class FirestoreService {

    static let shared = FirestoreService()
    private let db = Firestore.firestore()
    private init() {}

    private func userRef() throws -> DocumentReference {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw FirestoreError.notAuthenticated
        }
        return db.collection("users").document(uid)
    }

    // MARK: - Workouts

    func fetchWorkouts() async throws -> [WorkoutEntry] {
        let ref = try userRef()
        let snap = try await ref
            .collection("entries")
            .order(by: "date", descending: true)
            .getDocuments()

        return snap.documents.compactMap { doc in
            guard let date = (doc["date"] as? Timestamp)?.dateValue(),
                  let segments = doc["segments"] as? [String]
            else { return nil }

            return WorkoutEntry(
                id: doc.documentID,
                date: date,
                segments: segments
            )
        }
    }

    func saveWorkout(_ entry: WorkoutEntry) async throws {
        let ref = try userRef()
        let doc = ref.collection("entries").document(entry.id)
        try await doc.setData([
            "date": entry.date,
            "segments": entry.segments
        ])
    }

    func deleteWorkout(id: String) async throws {
        let ref = try userRef()
        try await ref.collection("entries").document(id).delete()
    }
}

// MARK: - Errors

enum FirestoreError: Error {
    case notAuthenticated
}
