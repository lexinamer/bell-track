import Foundation

// MARK: - Muscle Group

enum MuscleGroup: String, Codable, CaseIterable {
    case chest, back, shoulders, biceps, triceps
    case quads, hamstrings, glutes, calves
    case core, forearms, fullBody

    var displayName: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .quads: return "Quads"
        case .hamstrings: return "Hamstrings"
        case .glutes: return "Glutes"
        case .calves: return "Calves"
        case .core: return "Core"
        case .forearms: return "Forearms"
        case .fullBody: return "Full Body"
        }
    }
}

// MARK: - Exercise

struct Exercise: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var primaryMuscles: [MuscleGroup]
    var secondaryMuscles: [MuscleGroup]
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
