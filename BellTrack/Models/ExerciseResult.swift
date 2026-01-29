import Foundation

struct ExerciseResult: Identifiable {

    let id: String
    let exerciseId: String
    let values: [TrackingType: String]

    init(
        id: String = UUID().uuidString,
        exerciseId: String,
        values: [TrackingType: String]
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.values = values
    }

    // Firestore Init
    init?(from data: [String: Any]) {
        guard
            let id = data["id"] as? String,
            let exerciseId = data["exerciseId"] as? String,
            let rawValues = data["values"] as? [String: String]
        else {
            return nil
        }

        var parsed: [TrackingType: String] = [:]
        for (key, value) in rawValues {
            if let type = TrackingType(rawValue: key) {
                parsed[type] = value
            }
        }

        self.id = id
        self.exerciseId = exerciseId
        self.values = parsed
    }

    // Firestore Encoding
    var firestoreData: [String: Any] {
        [
            "id": id,
            "exerciseId": exerciseId,
            "values": Dictionary(
                uniqueKeysWithValues: values.map { ($0.key.rawValue, $0.value) }
            )
        ]
    }
}
