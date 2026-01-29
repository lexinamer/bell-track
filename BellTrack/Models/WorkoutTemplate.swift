import Foundation

struct WorkoutTemplate: Identifiable, Codable, Hashable {
    let id: String
    var name: String            // "A", "B"
    var exercises: [Exercise]

    init(
        id: String = UUID().uuidString,
        name: String,
        exercises: [Exercise]
    ) {
        self.id = id
        self.name = name
        self.exercises = exercises
    }
}
