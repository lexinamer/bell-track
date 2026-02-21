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

// MARK: - Exercise Mode

enum ExerciseMode: String, Codable {
    case reps
    case time
}

// MARK: - Exercise

struct Exercise: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var name: String
    var primaryMuscles: [MuscleGroup]
    var secondaryMuscles: [MuscleGroup]
    var mode: ExerciseMode
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
    var goal: String?
    var colorIndex: Int?
}

// MARK: - LogSet

struct LogSet: Identifiable, Codable, Equatable {
    let id: String
    var sets: Int?
    var reps: String?
    var weight: String?
    var isDouble: Bool
    var offsetWeight: String?

    init(
        id: String = UUID().uuidString,
        sets: Int? = nil,
        reps: String? = nil,
        weight: String? = nil,
        isDouble: Bool = false,
        offsetWeight: String? = nil
    ) {
        self.id = id
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.isDouble = isDouble
        self.offsetWeight = offsetWeight
    }
}

// MARK: - WorkoutLog

struct WorkoutLog: Identifiable, Codable, Equatable {
    let id: String
    var exerciseId: String
    var exerciseName: String
    var sets: [LogSet]
    var note: String?

    /// controls UI mode independently of sets.count
    var isVarying: Bool

    init(
        id: String = UUID().uuidString,
        exerciseId: String,
        exerciseName: String,
        sets: [LogSet] = [LogSet()],
        note: String? = nil,
        isVarying: Bool = false
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.sets = sets.isEmpty ? [LogSet()] : sets
        self.note = note
        self.isVarying = isVarying
    }

    // MARK: - Helpers

    var totalSets: Int {
        sets.reduce(0) { $0 + ($1.sets ?? 0) }
    }

    var totalReps: Int {
        sets.reduce(0) {
            $0 + (($1.sets ?? 0) * (Int($1.reps ?? "0") ?? 0))
        }
    }

    var totalVolume: Double {
        sets.reduce(0.0) { total, set in
            let reps = Double(set.reps ?? "0") ?? 0
            let base = Double(set.weight ?? "0") ?? 0
            let weight = set.isDouble ? base * 2 : base
            return total + Double(set.sets ?? 0) * reps * weight
        }
    }

    mutating func addRow() {
        let last = sets.last ?? LogSet()
        sets.append(
            LogSet(
                sets: last.sets,
                reps: last.reps,
                weight: last.weight,
                isDouble: last.isDouble
            )
        )
    }

    mutating func removeRow(at index: Int) {
        guard sets.count > 1 else { return }
        sets.remove(at: index)
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

// MARK: - Stats

struct ExerciseDetailStats {
    let totalWorkouts: Int
    let totalReps: Int
    let heaviestWeight: String?
    let mostSets: Int?
    let mostReps: String?
    let primaryMuscles: [MuscleGroup]
    let secondaryMuscles: [MuscleGroup]
}
