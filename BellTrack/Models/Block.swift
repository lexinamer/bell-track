import Foundation

struct Block: Identifiable, Codable {
    let id: String
    var name: String
    var startDate: Date
    var durationWeeks: Int
    var workouts: [WorkoutTemplate]

    init(
        id: String = UUID().uuidString,
        name: String,
        startDate: Date,
        durationWeeks: Int,
        workouts: [WorkoutTemplate]
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.durationWeeks = durationWeeks
        self.workouts = workouts
    }
}
