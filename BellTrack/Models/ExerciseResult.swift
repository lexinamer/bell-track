import Foundation

struct ExerciseResult: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var exerciseId: String
    var exerciseName: String
    var trackingType: TrackingType
    var value: String

    init(
        id: String = UUID().uuidString,
        exerciseId: String,
        exerciseName: String,
        trackingType: TrackingType,
        value: String = ""
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.trackingType = trackingType
        self.value = value
    }

    var firestoreData: [String: Any] {
        [
            "id": id,
            "exerciseId": exerciseId,
            "exerciseName": exerciseName,
            "trackingType": trackingType.rawValue,
            "value": value
        ]
    }

    init?(from data: [String: Any]) {
        guard
            let id = data["id"] as? String,
            let exerciseId = data["exerciseId"] as? String,
            let exerciseName = data["exerciseName"] as? String,
            let trackingTypeRaw = data["trackingType"] as? String,
            let trackingType = TrackingType(rawValue: trackingTypeRaw),
            let value = data["value"] as? String
        else { return nil }

        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.trackingType = trackingType
        self.value = value
    }

    var hasValue: Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
