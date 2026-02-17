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
            let modeString = doc["mode"] as? String ?? "reps"
            let mode = ExerciseMode(rawValue: modeString) ?? .reps

            return Exercise(
                id: doc.documentID,
                name: doc["name"] as? String ?? "",
                primaryMuscles: primaryRaw.compactMap { MuscleGroup(rawValue: $0) },
                secondaryMuscles: secondaryRaw.compactMap { MuscleGroup(rawValue: $0) },
                mode: mode
            )
        }
    }

    func saveExercise(
        id: String?,
        name: String,
        primaryMuscles: [MuscleGroup],
        secondaryMuscles: [MuscleGroup],
        mode: ExerciseMode
    ) async throws {
        let ref = try userRef()
        let doc = id == nil
            ? ref.collection("exercises").document()
            : ref.collection("exercises").document(id!)

        let data: [String: Any] = [
            "name": name,
            "primaryMuscles": primaryMuscles.map { $0.rawValue },
            "secondaryMuscles": secondaryMuscles.map { $0.rawValue },
            "mode": mode.rawValue
        ]

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

        let defaults: [(name: String, primary: [MuscleGroup], secondary: [MuscleGroup], mode: ExerciseMode)] = [
            ("Clean", [.glutes, .hamstrings], [.core, .forearms], .reps),
            ("Clean to Press", [.glutes, .shoulders, .hamstrings],  [.core, .forearms, .triceps], .reps),
            ("Farmer Carry", [.forearms, .core], [.shoulders, .glutes, .back], .time),
            ("Front Squat", [.quads, .glutes], [.core, .hamstrings, .back], .reps),
            ("Goblet Squat", [.quads, .glutes], [.core, .hamstrings, .back, .shoulders], .reps),
            ("Lunge", [.quads, .glutes], [.hamstrings, .core, .calves], .reps),
            ("Press", [.shoulders], [.triceps, .core, .forearms, .back], .reps),
            ("Pushup", [.chest], [.triceps, .shoulders, .core, .glutes], .reps),
            ("RDL", [.hamstrings, .glutes], [.core, .back, .forearms], .reps),
            ("Row", [.back], [.biceps, .core, .forearms, .shoulders], .reps),
            ("Snatch", [.glutes, .hamstrings, .shoulders], [.core, .back, .forearms, .quads], .reps),
            ("Suitcase Carry", [.core, .forearms], [.shoulders, .glutes, .back], .time),
            ("Swing", [.glutes, .hamstrings], [.core, .back, .forearms, .shoulders], .reps)
        ]

        for exercise in defaults {
            let doc = ref.collection("exercises").document()
            try await doc.setData([
                "name": exercise.name,
                "primaryMuscles": exercise.primary.map { $0.rawValue },
                "secondaryMuscles": exercise.secondary.map { $0.rawValue },
                "mode": exercise.mode.rawValue
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

        return snap.documents.compactMap { doc -> Block? in
            guard
                let name = doc["name"] as? String,
                let startDate = (doc["startDate"] as? Timestamp)?.dateValue()
            else { return nil }

            let endDate = (doc["endDate"] as? Timestamp)?.dateValue()
            let completedDate = (doc["completedDate"] as? Timestamp)?.dateValue()

            return Block(
                id: doc.documentID,
                name: name,
                startDate: startDate,
                endDate: endDate,
                completedDate: completedDate
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
        notes: String? = nil
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

                return WorkoutLog(
                    id: id,
                    exerciseId: exerciseId,
                    exerciseName: exerciseName,
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
