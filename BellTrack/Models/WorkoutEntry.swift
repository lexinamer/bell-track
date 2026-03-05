import Foundation

struct WorkoutEntry: Identifiable, Codable {
    let id: String
    var date: Date
    var segments: [String]

    init(id: String = UUID().uuidString, date: Date = Date(), segments: [String] = [""]) {
        self.id = id
        self.date = date
        self.segments = segments
    }
}
