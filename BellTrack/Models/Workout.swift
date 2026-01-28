import Foundation

struct Workout: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var exercises: [Exercise]

    init(id: String = UUID().uuidString, name: String, exercises: [Exercise] = []) {
        self.id = id
        self.name = name
        self.exercises = exercises
    }

    var firestoreData: [String: Any] {
        [
            "id": id,
            "name": name,
            "exercises": exercises.map { $0.firestoreData }
        ]
    }

    init?(from data: [String: Any]) {
        guard
            let id = data["id"] as? String,
            let name = data["name"] as? String
        else { return nil }

        self.id = id
        self.name = name

        if let exercisesData = data["exercises"] as? [[String: Any]] {
            self.exercises = exercisesData.compactMap(Exercise.init(from:))
        } else {
            self.exercises = []
        }
    }
}
