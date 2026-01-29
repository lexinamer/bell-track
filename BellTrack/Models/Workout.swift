import Foundation

struct Workout: Identifiable, Codable {

    let id: String
    let blockID: String
    let workoutTemplateID: String
    let workoutName: String
    let date: Date
    let results: [ExerciseResult]

    init(
        id: String = UUID().uuidString,
        blockID: String,
        workoutTemplateID: String,
        workoutName: String,
        date: Date,
        results: [ExerciseResult]
    ) {
        self.id = id
        self.blockID = blockID
        self.workoutTemplateID = workoutTemplateID
        self.workoutName = workoutName
        self.date = date
        self.results = results
    }
}
