import Foundation
import FirebaseFirestore

struct UserSettings: Codable {
    @DocumentID var id: String?
    var userId: String
    var units: WeightUnit
    
    enum WeightUnit: String, Codable {
        case kg = "kg"
        case lbs = "lbs"
    }
}
