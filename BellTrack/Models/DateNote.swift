import Foundation
import FirebaseFirestore

struct DateNote: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var date: Date
    var note: String
}
