import Foundation
import FirebaseFirestore

struct WorkoutLog: Identifiable {

    let id: String
    let workoutId: String
    let date: Date
    let exerciseResults: [ExerciseResult]

    init(
        id: String = UUID().uuidString,
        workoutId: String,
        date: Date,
        exerciseResults: [ExerciseResult]
    ) {
        self.id = id
        self.workoutId = workoutId
        self.date = date
        self.exerciseResults = exerciseResults
    }

    // Firestore Init
    init?(from document: DocumentSnapshot) {
        let data = document.data() ?? [:]

        guard
            let workoutId = data["workoutId"] as? String,
            let timestamp = data["date"] as? Timestamp,
            let resultsData = data["exerciseResults"] as? [[String: Any]]
        else {
            return nil
        }

        self.id = document.documentID
        self.workoutId = workoutId
        self.date = timestamp.dateValue()
        self.exerciseResults = resultsData.compactMap {
            ExerciseResult(from: $0)
        }
    }

    // Firestore Encoding
    var firestoreData: [String: Any] {
        [
            "workoutId": workoutId,
            "date": Timestamp(date: date),
            "exerciseResults": exerciseResults.map { $0.firestoreData }
        ]
    }
}
