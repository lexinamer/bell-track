import Foundation
import FirebaseFirestore

struct WorkoutLog: Identifiable, Codable, Equatable {
    var id: String?
    var userId: String
    var blockId: String
    var workoutId: String
    var workoutName: String
    var date: Date
    var exerciseResults: [ExerciseResult]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String? = nil,
        userId: String,
        blockId: String,
        workoutId: String,
        workoutName: String,
        date: Date = Date(),
        exerciseResults: [ExerciseResult] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.blockId = blockId
        self.workoutId = workoutId
        self.workoutName = workoutName
        self.date = date
        self.exerciseResults = exerciseResults
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

extension WorkoutLog {
    init?(from doc: DocumentSnapshot) {
        guard
            let data = doc.data(),
            let userId = data["userId"] as? String,
            let blockId = data["blockId"] as? String,
            let workoutId = data["workoutId"] as? String,
            let workoutName = data["workoutName"] as? String,
            let dateTimestamp = data["date"] as? Timestamp
        else { return nil }

        var exerciseResults: [ExerciseResult] = []
        if let resultsData = data["exerciseResults"] as? [[String: Any]] {
            exerciseResults = resultsData.compactMap(ExerciseResult.init(from:))
        }

        self.init(
            id: doc.documentID,
            userId: userId,
            blockId: blockId,
            workoutId: workoutId,
            workoutName: workoutName,
            date: dateTimestamp.dateValue(),
            exerciseResults: exerciseResults,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? dateTimestamp.dateValue(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    var firestoreData: [String: Any] {
        [
            "userId": userId,
            "blockId": blockId,
            "workoutId": workoutId,
            "workoutName": workoutName,
            "date": Timestamp(date: date),
            "exerciseResults": exerciseResults.map { $0.firestoreData },
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: Date())
        ]
    }
}
