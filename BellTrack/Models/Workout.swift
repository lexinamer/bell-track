import Foundation
import FirebaseFirestore

struct WorkoutBlock: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var date: Date
    var exercises: [Exercise]
    var rounds: Int
    var type: BlockType
    var style: BlockStyle
    var weight: Int
    
    enum BlockType: String, Codable {
        case emom = "EMOM"
        case amrap = "AMRAP"
        case sets = "SETS"
    }
    
    enum BlockStyle: String, Codable {
        case single = "Single"
        case double = "Double"
        case twoHanded = "Two-Handed"
    }
}

struct Exercise: Codable, Identifiable {
    var id = UUID()
    var name: String
    var reps: Int
}
