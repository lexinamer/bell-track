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
}

// MARK: - Complex

struct Complex: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var name: String
    var exerciseIds: [String]
}

struct ResolvedComplex: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let exerciseIds: [String]
    let primaryMuscles: [MuscleGroup]
    let secondaryMuscles: [MuscleGroup]
}

extension Complex {
    func resolved(with exercises: [Exercise]) -> ResolvedComplex {
        let components = exercises.filter { exerciseIds.contains($0.id) }
        let allPrimary = Array(Set(components.flatMap { $0.primaryMuscles }))
        let allSecondary = Array(Set(components.flatMap { $0.secondaryMuscles }))
        // Remove any muscle that appears in primary from secondary
        let filteredSecondary = allSecondary.filter { !allPrimary.contains($0) }

        return ResolvedComplex(
            id: id,
            name: name,
            exerciseIds: exerciseIds,
            primaryMuscles: allPrimary,
            secondaryMuscles: filteredSecondary
        )
    }
}

// MARK: - Workout Template

struct TemplateEntry: Identifiable, Codable, Equatable {
    let id: String
    var exerciseId: String
    var exerciseName: String
    var isComplex: Bool

    init(
        id: String = UUID().uuidString,
        exerciseId: String,
        exerciseName: String,
        isComplex: Bool = false
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.isComplex = isComplex
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
    var notes: String?
    var colorIndex: Int?
}

// MARK: - WorkoutLog

struct WorkoutLog: Identifiable, Codable, Equatable {
    let id: String

    var exerciseId: String
    var exerciseName: String
    var isComplex: Bool

    var sets: Int?
    var reps: String?
    var weight: String?
    var note: String?

    init(
        id: String,
        exerciseId: String,
        exerciseName: String,
        isComplex: Bool = false,
        sets: Int? = nil,
        reps: String? = nil,
        weight: String? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.isComplex = isComplex
        self.sets = sets
        self.reps = reps
        self.weight = weight
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
    let totalSets: Int
    let heaviestWeight: String?
    let mostSets: Int?
    let mostReps: String?
    let primaryMuscles: [MuscleGroup]
    let secondaryMuscles: [MuscleGroup]
}
