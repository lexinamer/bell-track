import Foundation
import FirebaseFirestore

struct Workout: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var date: Date
    var exercises: [Exercise]
    
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}
