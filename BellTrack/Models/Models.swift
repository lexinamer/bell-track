import Foundation

// MARK: - Muscle Group

enum MuscleGroup: String, Codable, CaseIterable {
    case chest, back, shoulders, biceps, triceps
    case quads, hamstrings, glutes, calves
    case core, forearms

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
        }
    }
}

// MARK: - Exercise

struct Exercise: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var name: String
    var primaryMuscles: [MuscleGroup]
    var secondaryMuscles: [MuscleGroup]
    var mode: ExerciseMode  // How this exercise is tracked (reps or time)
}

// MARK: - Workout Template

struct TemplateEntry: Identifiable, Codable, Equatable {
    let id: String
    var exerciseId: String
    var exerciseName: String

    init(
        id: String = UUID().uuidString,
        exerciseId: String,
        exerciseName: String
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
    }
}

struct WorkoutTemplate: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var blockId: String
    var entries: [TemplateEntry]
}

// MARK: - Block

struct Block: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var name: String
    var startDate: Date
    var endDate: Date?
    var completedDate: Date?
}

// MARK: - Exercise Mode

enum ExerciseMode: String, Codable {
    case reps
    case time
}

// MARK: - WorkoutLog

struct WorkoutLog: Identifiable, Codable, Equatable {
    let id: String

    var exerciseId: String
    var exerciseName: String

    var sets: Int?
    var reps: String?  // Can be number (reps mode) or time string (time mode)
    var weight: String?
    var isDouble: Bool  // Double toggle: false = "12kg", true = "2×12kg"
    var note: String?

    init(
        id: String,
        exerciseId: String,
        exerciseName: String,
        sets: Int? = nil,
        reps: String? = nil,
        weight: String? = nil,
        isDouble: Bool = false,
        note: String? = nil
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.isDouble = isDouble
        self.note = note
    }
}

// MARK: - Workout

struct Workout: Identifiable, Codable, Equatable {
    let id: String
    var name: String?
    var date: Date
    var blockId: String?
    var logs: [WorkoutLog]
}

// MARK: - Stats (used in Detail view)

struct ExerciseDetailStats {
    let totalWorkouts: Int
    let totalReps: Int
    let heaviestWeight: String?
    let mostSets: Int?
    let mostReps: String?
    let primaryMuscles: [MuscleGroup]
    let secondaryMuscles: [MuscleGroup]
}
