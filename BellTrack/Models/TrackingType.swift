import Foundation

enum TrackingType: String, Codable, CaseIterable, Identifiable {
    case weightReps = "weight_reps"
    case reps = "reps"
    case time = "time"
    case notes = "notes"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weightReps: return "Weight × Reps"
        case .reps: return "Reps"
        case .time: return "Time"
        case .notes: return "Notes"
        }
    }

    var placeholder: String {
        switch self {
        case .weightReps: return "135×8, 145×6, 155×4"
        case .reps: return "12, 10, 8"
        case .time: return "30s, 45s, 60s"
        case .notes: return "Notes..."
        }
    }
}
