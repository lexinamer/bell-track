import Foundation
import FirebaseFirestore

struct ExerciseDefinition: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var isHidden: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, name, isHidden
    }

    init(id: UUID = UUID(), name: String, isHidden: Bool = false) {
        self.id = id
        self.name = name
        self.isHidden = isHidden
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
    }
}

struct Settings: Codable {
    @DocumentID var id: String?
    var userId: String
    var exercises: [ExerciseDefinition]

    static let defaultExerciseNames = ["C&P", "Squat", "Swing", "Row", "Snatch", "Lunge", "RDL", "Carry", "Pushup"]

    static var defaultExercises: [ExerciseDefinition] {
        defaultExerciseNames.map { ExerciseDefinition(name: $0) }
    }

    var visibleExercises: [ExerciseDefinition] {
        exercises.filter { !$0.isHidden }
    }

    var visibleExerciseNames: [String] {
        visibleExercises.map { $0.name }
    }
}
