import Foundation
import FirebaseFirestore

struct Settings: Codable {
    @DocumentID var id: String?
    var userId: String
    var exercises: [String]
    
    static let defaultExercises = ["C&P", "Squat", "Swing", "Row", "Snatch", "Lunge", "RDL", "Carry", "Pushup"]
}
