import Foundation

struct ExerciseResult: Identifiable, Codable {
    let id: String
    let exerciseID: String
    let values: [TrackingType: String]

    init(
        id: String = UUID().uuidString,
        exerciseID: String,
        values: [TrackingType: String]
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.values = values
    }
}
