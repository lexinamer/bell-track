import Foundation

enum TrackingType: String, Codable, CaseIterable, Hashable {
    case weight
    case reps
    case time
    case effort
}
