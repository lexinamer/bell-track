import Foundation
import FirebaseFirestore

struct WorkoutBlock: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var date: Date
    var exercises: [Exercise]
    var rounds: Int
    var type: BlockType?  // Now optional
    var style: BlockStyle?  // Now optional
    var weight: Int?  // Now optional
    var unit: String
    var time: Double?  // New - time in seconds or minutes
    var timeUnit: String?  // New - "s" or "min"
    
    enum BlockType: String, Codable {
        case emom = "EMOM"
        case amrap = "AMRAP"
        case sets = "Sets"
    }
    
    enum BlockStyle: String, Codable {
        case single = "Single"
        case double = "Double"
        case twoHanded = "Two-Handed"
    }
}

struct Exercise: Identifiable, Codable {
    var id = UUID()
    var name: String
    var reps: Int?  // Now optional
}
