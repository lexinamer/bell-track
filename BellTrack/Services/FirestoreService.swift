import Foundation
import FirebaseFirestore
import FirebaseAuth

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

        return snap.documents.map { doc in
            let primaryRaw = doc["primaryMuscles"] as? [String] ?? []
            let secondaryRaw = doc["secondaryMuscles"] as? [String] ?? []
            let exerciseIds = doc["exerciseIds"] as? [String]

            return Exercise(
                id: doc.documentID,
                name: doc["name"] as? String ?? "",
                primaryMuscles: primaryRaw.compactMap { MuscleGroup(rawValue: $0) },
                secondaryMuscles: secondaryRaw.compactMap { MuscleGroup(rawValue: $0) },
                exerciseIds: exerciseIds
            )
        }
    }

    func saveExercise(
        id: String?,
        name: String,
        primaryMuscles: [MuscleGroup],
        secondaryMuscles: [MuscleGroup],
        exerciseIds: [String]? = nil
    ) async throws {
        let ref = try userRef()
        let doc = id == nil
            ? ref.collection("exercises").document()
            : ref.collection("exercises").document(id!)

        var data: [String: Any] = [
            "name": name,
            "primaryMuscles": primaryMuscles.map { $0.rawValue },
            "secondaryMuscles": secondaryMuscles.map { $0.rawValue }
        ]

        if let exerciseIds = exerciseIds {
            data["exerciseIds"] = exerciseIds
        }

        try await doc.setData(data)
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

            for i in 0..<updatedLogs.count {
                if updatedLogs[i].exerciseId == exerciseId {
                    updatedLogs[i].exerciseName = newName
                    needsUpdate = true
                }
            }

            if needsUpdate {
                try await saveWorkout(
                    id: workout.id,
                    name: workout.name,
                    date: workout.date,
                    blockId: workout.blockId,
                    logs: updatedLogs
                )
            }
        }
    }


    // MARK: - Default Exercise Seeding

    func seedDefaultExercisesIfNeeded() async throws {
        let ref = try userRef()

        let snap = try await ref.collection("exercises").limit(to: 1).getDocuments()
        guard snap.documents.isEmpty else { return }

        let defaults: [(name: String, primary: [MuscleGroup], secondary: [MuscleGroup])] = [
            ("Press", [.shoulders, .triceps], [.core]),
            ("Clean", [.hamstrings, .glutes, .back], [.quads, .forearms]),
            ("Squat", [.quads], [.hamstrings, .glutes]),
            ("Swing", [.hamstrings, .glutes], [.core, .back]),
        ]

        for exercise in defaults {
            let doc = ref.collection("exercises").document()
            try await doc.setData([
                "name": exercise.name,
                "primaryMuscles": exercise.primary.map { $0.rawValue },
                "secondaryMuscles": exercise.secondary.map { $0.rawValue },
            ])
        }
    }

    // MARK: - Workout Templates

    func fetchWorkoutTemplates() async throws -> [WorkoutTemplate] {
        let ref = try userRef()

        let snap = try await ref
            .collection("workoutTemplates")
            .order(by: "name")
            .getDocuments()

        return snap.documents.compactMap { doc in
            guard
                let name = doc["name"] as? String,
                let blockId = doc["blockId"] as? String,
                let entriesData = doc["entries"] as? [[String: Any]]
            else { return nil }

            let entries: [TemplateEntry] = entriesData.compactMap { entry in
                guard
                    let id = entry["id"] as? String,
                    let exerciseId = entry["exerciseId"] as? String,
                    let exerciseName = entry["exerciseName"] as? String
                else { return nil }

                return TemplateEntry(
                    id: id,
                    exerciseId: exerciseId,
                    exerciseName: exerciseName
                )
            }

            return WorkoutTemplate(
                id: doc.documentID,
                name: name,
                blockId: blockId,
                entries: entries
            )
        }
    }

    func saveWorkoutTemplate(
        id: String?,
        name: String,
        blockId: String,
        entries: [TemplateEntry]
    ) async throws {
        let ref = try userRef()
        let doc = id == nil
            ? ref.collection("workoutTemplates").document()
            : ref.collection("workoutTemplates").document(id!)

        let entriesPayload = entries.map {
            [
                "id": $0.id,
                "exerciseId": $0.exerciseId,
                "exerciseName": $0.exerciseName
            ] as [String: Any]
        }

        try await doc.setData([
            "name": name,
            "blockId": blockId,
            "entries": entriesPayload
        ])
    }

    func deleteWorkoutTemplate(id: String) async throws {
        let ref = try userRef()
        try await ref.collection("workoutTemplates").document(id).delete()
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
                let startDate = (doc["startDate"] as? Timestamp)?.dateValue()
            else { return nil }

            let endDate = (doc["endDate"] as? Timestamp)?.dateValue()
            let completedDate = (doc["completedDate"] as? Timestamp)?.dateValue()
            let notes = doc["notes"] as? String

            return Block(
                id: doc.documentID,
                name: name,
                startDate: startDate,
                endDate: endDate,
                completedDate: completedDate,
                notes: notes,
                colorIndex: doc["colorIndex"] as? Int
            )
        }
    }

    @discardableResult
    func saveBlock(
        id: String?,
        name: String,
        startDate: Date,
        endDate: Date? = nil,
        completedDate: Date? = nil,
        notes: String? = nil,
        colorIndex: Int? = nil
    ) async throws -> String {

        let ref = try userRef()
        let doc = id == nil
            ? ref.collection("blocks").document()
            : ref.collection("blocks").document(id!)

        var data: [String: Any] = [
            "name": name,
            "startDate": startDate
        ]

        if let endDate = endDate {
            data["endDate"] = endDate
        }

        if let completedDate = completedDate {
            data["completedDate"] = completedDate
        }

        if let notes = notes {
            data["notes"] = notes
        }

        if let colorIndex = colorIndex {
            data["colorIndex"] = colorIndex
        }

        try await doc.setData(data)
        return doc.documentID
    }

    func deleteBlock(id: String) async throws {
        let ref = try userRef()
        try await ref.collection("blocks").document(id).delete()
    }

    func completeBlock(id: String) async throws {
        let ref = try userRef()
        try await ref.collection("blocks").document(id).updateData([
            "completedDate": Date()
        ])
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

                let modeString = log["mode"] as? String ?? "reps"
                let mode = ExerciseMode(rawValue: modeString) ?? .reps

                return WorkoutLog(
                    id: id,
                    exerciseId: exerciseId,
                    exerciseName: exerciseName,
                    mode: mode,
                    sets: log["sets"] as? Int,
                    reps: log["reps"] as? String,
                    weight: log["weight"] as? String,
                    isDouble: log["isDouble"] as? Bool ?? false,
                    note: log["note"] as? String
                )
            }

            return Workout(
                id: doc.documentID,
                name: doc["name"] as? String,
                date: date,
                blockId: doc["blockId"] as? String,
                logs: logs
            )
        }
    }

    func saveWorkout(
        id: String?,
        name: String?,
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
                "mode": $0.mode.rawValue,
                "sets": $0.sets as Any,
                "reps": $0.reps as Any,
                "weight": $0.weight as Any,
                "isDouble": $0.isDouble,
                "note": $0.note as Any
            ]
        }

        try await doc.setData([
            "date": date,
            "name": name as Any,
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
