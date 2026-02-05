import Foundation

// MARK: - Exercise

struct Exercise: Identifiable, Codable, Equatable {
    let id: String
    var name: String
}

// MARK: - Block

enum BlockType: String, Codable, CaseIterable {
    case duration
    case ongoing
}

struct Block: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var startDate: Date
    var type: BlockType
    var durationWeeks: Int?
    var completedDate: Date?
    var notes: String?
    var colorIndex: Int?
}

// MARK: - WorkoutLog

struct WorkoutLog: Identifiable, Codable, Equatable {
    let id: String

    var exerciseId: String
    var exerciseName: String

    var sets: Int?
    var reps: String?
    var weight: String?
    var note: String?
}

// MARK: - Workout

struct Workout: Identifiable, Codable, Equatable {
    let id: String
    var name: String?
    var date: Date
    var blockId: String?
    var logs: [WorkoutLog]
}
