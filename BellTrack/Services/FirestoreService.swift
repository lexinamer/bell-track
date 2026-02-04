import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class FirestoreService {

    private let db = Firestore.firestore()

    private func userRef() throws -> DocumentReference {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw FirestoreError.notAuthenticated
        }
        return db.collection("users").document(uid)
    }

    // MARK: - Exercises

    func fetchExercises() async throws -> [Exercise] {
        let ref = try userRef()

        let snap = try await ref
            .collection("exercises")
            .order(by: "name")
            .getDocuments()

        return snap.documents.map {
            Exercise(
                id: $0.documentID,
                name: $0["name"] as? String ?? ""
            )
        }
    }

    func saveExercise(id: String?, name: String) async throws {
        let ref = try userRef()
        let doc = id == nil
            ? ref.collection("exercises").document()
            : ref.collection("exercises").document(id!)

        try await doc.setData([
            "name": name
        ])
    }

    func deleteExercise(id: String) async throws {
        let ref = try userRef()
        try await ref.collection("exercises").document(id).delete()
    }
    
    // MARK: - Update Exercise Names in Workouts
    
    func updateExerciseNameInWorkouts(exerciseId: String, newName: String) async throws {
        let workouts = try await fetchWorkouts()
        
        for workout in workouts {
            var needsUpdate = false
            var updatedLogs = workout.logs
            
            // Update any logs that match this exercise ID
            for i in 0..<updatedLogs.count {
                if updatedLogs[i].exerciseId == exerciseId {
                    updatedLogs[i].exerciseName = newName
                    needsUpdate = true
                }
            }
            
            // Save the workout if any logs were updated
            if needsUpdate {
                try await saveWorkout(
                    id: workout.id,
                    date: workout.date,
                    blockId: workout.blockId,
                    logs: updatedLogs
                )
            }
        }
    }

    // MARK: - Blocks

    func fetchBlocks() async throws -> [Block] {
        let ref = try userRef()

        let snap = try await ref
            .collection("blocks")
            .order(by: "startDate", descending: true)
            .getDocuments()

        return snap.documents.compactMap { doc in
            guard
                let name = doc["name"] as? String,
                let startDate = (doc["startDate"] as? Timestamp)?.dateValue(),
                let typeRaw = doc["type"] as? String,
                let type = BlockType(rawValue: typeRaw)
            else { return nil }

            return Block(
                id: doc.documentID,
                name: name,
                startDate: startDate,
                type: type,
                durationWeeks: doc["durationWeeks"] as? Int
            )
        }
    }

    func saveBlock(
        id: String?,
        name: String,
        startDate: Date,
        type: BlockType,
        durationWeeks: Int?
    ) async throws {

        let ref = try userRef()
        let doc = id == nil
            ? ref.collection("blocks").document()
            : ref.collection("blocks").document(id!)

        try await doc.setData([
            "name": name,
            "startDate": startDate,
            "type": type.rawValue,
            "durationWeeks": durationWeeks as Any
        ])
    }

    func deleteBlock(id: String) async throws {
        let ref = try userRef()
        try await ref.collection("blocks").document(id).delete()
    }

    // MARK: - Workouts

    func fetchWorkouts() async throws -> [Workout] {
        let ref = try userRef()

        let snap = try await ref
            .collection("workouts")
            .order(by: "date", descending: true)
            .getDocuments()

        return snap.documents.compactMap { doc in
            guard
                let date = (doc["date"] as? Timestamp)?.dateValue(),
                let logsData = doc["logs"] as? [[String: Any]]
            else { return nil }

            let logs: [WorkoutLog] = logsData.compactMap { log in
                guard
                    let id = log["id"] as? String,
                    let exerciseId = log["exerciseId"] as? String,
                    let exerciseName = log["exerciseName"] as? String
                else { return nil }

                return WorkoutLog(
                    id: id,
                    exerciseId: exerciseId,
                    exerciseName: exerciseName,
                    sets: log["sets"] as? Int,
                    reps: log["reps"] as? String,
                    weight: log["weight"] as? String,  // Now String instead of Double
                    note: log["note"] as? String
                )
            }

            return Workout(
                id: doc.documentID,
                date: date,
                blockId: doc["blockId"] as? String,
                logs: logs
            )
        }
    }

    func saveWorkout(
        id: String?,
        date: Date,
        blockId: String?,
        logs: [WorkoutLog]
    ) async throws {

        let ref = try userRef()
        let doc = id == nil
            ? ref.collection("workouts").document()
            : ref.collection("workouts").document(id!)

        let logsPayload = logs.map {
            [
                "id": $0.id,
                "exerciseId": $0.exerciseId,
                "exerciseName": $0.exerciseName,
                "sets": $0.sets as Any,
                "reps": $0.reps as Any,
                "weight": $0.weight as Any,  // Now handles String weight
                "note": $0.note as Any
            ]
        }

        try await doc.setData([
            "date": date,
            "blockId": blockId as Any,
            "logs": logsPayload
        ])
    }

    func deleteWorkout(id: String) async throws {
        let ref = try userRef()
        try await ref.collection("workouts").document(id).delete()
    }
}

// MARK: - Errors

enum FirestoreError: Error {
    case notAuthenticated
}
