import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class FirestoreService {

    private let db = Firestore.firestore()

    // MARK: - Helpers

    private func userRef() throws -> DocumentReference {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw FirestoreError.noUser
        }
        return db.collection("users").document(uid)
    }

    // MARK: - Blocks

    func fetchBlocks() async throws -> [Block] {
        let snapshot = try await userRef()
            .collection("blocks")
            .order(by: "startDate", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            guard
                let name = doc["name"] as? String,
                let startDate = (doc["startDate"] as? Timestamp)?.dateValue(),
                let durationRaw = doc["duration"] as? Int,
                let duration = BlockDuration(rawValue: durationRaw)
            else {
                return nil
            }

            return Block(
                id: doc.documentID,
                name: name,
                startDate: startDate,
                duration: duration
            )
        }
    }

    func saveBlock(_ block: Block) async throws {
        let data: [String: Any] = [
            "name": block.name,
            "startDate": block.startDate,
            "duration": block.duration.rawValue
        ]

        if block.id.isEmpty {
            try await userRef()
                .collection("blocks")
                .addDocument(data: data)
        } else {
            try await userRef()
                .collection("blocks")
                .document(block.id)
                .setData(data, merge: true)
        }
    }

    func deleteBlock(_ blockId: String) async throws {
        try await userRef()
            .collection("blocks")
            .document(blockId)
            .delete()
    }

    // MARK: - Workouts

    func fetchWorkouts(for blockId: String) async throws -> [Workout] {
        let snapshot = try await userRef()
            .collection("blocks")
            .document(blockId)
            .collection("workouts")
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            guard let name = doc["name"] as? String else { return nil }

            let exercisesData = doc["exercises"] as? [[String: Any]] ?? []

            let exercises: [Exercise] = exercisesData.compactMap { data in
                guard
                    let id = data["id"] as? String,
                    let name = data["name"] as? String,
                    let rawTypes = data["trackingTypes"] as? [String]
                else { return nil }

                let types = rawTypes.compactMap { TrackingType(rawValue: $0) }

                return Exercise(
                    id: id,
                    name: name,
                    trackingTypes: types
                )
            }

            return Workout(
                id: doc.documentID,
                blockId: blockId,
                name: name,
                exercises: exercises
            )
        }
    }

    func saveWorkout(_ workout: Workout) async throws {
        let exercisesData: [[String: Any]] = workout.exercises.map {
            [
                "id": $0.id,
                "name": $0.name,
                "trackingTypes": $0.trackingTypes.map { $0.rawValue }
            ]
        }

        let data: [String: Any] = [
            "name": workout.name,
            "exercises": exercisesData
        ]

        try await userRef()
            .collection("blocks")
            .document(workout.blockId)
            .collection("workouts")
            .document(workout.id)
            .setData(data, merge: true)
    }

    // MARK: - Logs

    func fetchLogs(for workoutId: String) async throws -> [WorkoutLog] {
        let snapshot = try await userRef()
            .collection("logs")
            .whereField("workoutId", isEqualTo: workoutId)
            .order(by: "date", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            guard
                let workoutId = doc["workoutId"] as? String,
                let date = (doc["date"] as? Timestamp)?.dateValue(),
                let resultsData = doc["exerciseResults"] as? [[String: Any]]
            else { return nil }

            let results: [ExerciseResult] = resultsData.compactMap { data in
                guard
                    let exerciseId = data["exerciseId"] as? String,
                    let values = data["values"] as? [String: String]
                else { return nil }

                let mappedValues = Dictionary(
                    uniqueKeysWithValues:
                        values.compactMap { key, value in
                            TrackingType(rawValue: key).map { ($0, value) }
                        }
                )

                return ExerciseResult(
                    exerciseId: exerciseId,
                    values: mappedValues
                )
            }

            return WorkoutLog(
                id: doc.documentID,
                workoutId: workoutId,
                date: date,
                exerciseResults: results
            )
        }
    }

    func saveWorkoutLog(_ log: WorkoutLog) async throws {
        let resultsData: [[String: Any]] = log.exerciseResults.map {
            [
                "exerciseId": $0.exerciseId,
                "values": Dictionary(
                    uniqueKeysWithValues:
                        $0.values.map { ($0.key.rawValue, $0.value) }
                )
            ]
        }

        let data: [String: Any] = [
            "workoutId": log.workoutId,
            "date": log.date,
            "exerciseResults": resultsData
        ]

        try await userRef()
            .collection("logs")
            .document(log.id)
            .setData(data)
    }
}

// MARK: - Errors

enum FirestoreError: Error {
    case noUser
}
