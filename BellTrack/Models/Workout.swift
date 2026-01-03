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
    var isTracked: Bool

    // Load (weight) – always kg for now
    var loadKg: Double?          // e.g. 12, 16, 24
    var loadMode: LoadMode?      // single / double

    // Volume (reps or rounds)
    var volumeCount: Double?     // e.g. 30
    var volumeKind: VolumeKind?  // reps / rounds
}

// MARK: - Enums

enum LoadMode: String, Codable {
    case single
    case double
}

enum VolumeKind: String, Codable {
    case reps
    case rounds
}
