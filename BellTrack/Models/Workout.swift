import Foundation

struct Workout: Identifiable {
    let id: String
    let blockId: String

    // MUST be var for editors
    var name: String
    var exercises: [Exercise]

    init(
        id: String = UUID().uuidString,
        blockId: String,
        name: String,
        exercises: [Exercise] = []
    ) {
        self.id = id
        self.blockId = blockId
        self.name = name
        self.exercises = exercises
    }
}
