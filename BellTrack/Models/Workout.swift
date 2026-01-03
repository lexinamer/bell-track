import Foundation
import FirebaseFirestore

struct WorkoutBlock: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var date: Date
    var createdAt: Date
    
    // Core fields
    var name: String
    var details: String
    var isTracked: Bool  // Hearted or not
    
    // Tracking fields
    var trackType: TrackType?  // weight, time, or reps
    var trackValue: Double?    // 16 or 150 (seconds)
    var trackUnit: String?     // "kg", "lbs", or null for time
    
    enum TrackType: String, Codable {
        case weight = "weight"
        case time = "time"
        case reps = "reps"
    }
}
