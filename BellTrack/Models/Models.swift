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

// MARK: - Workout Type

enum WorkoutType: String, Codable {
    case strict
    case timed

    var displayName: String {
        switch self {
        case .strict: return "Strict"
        case .timed: return "Timed"
        }
    }
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

struct WorkoutTemplate: Identifiable, Equatable {
    let id: String
    var name: String
    var blockId: String
    var entries: [TemplateEntry]
    var workoutType: WorkoutType
    var duration: Int?  // minutes, Timed only

    init(
        id: String = UUID().uuidString,
        name: String,
        blockId: String,
        entries: [TemplateEntry] = [],
        workoutType: WorkoutType = .strict,
        duration: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.blockId = blockId
        self.entries = entries
        self.workoutType = workoutType
        self.duration = duration
    }
}

extension WorkoutTemplate: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, blockId, entries, workoutType, duration
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        blockId = try c.decode(String.self, forKey: .blockId)
        entries = try c.decodeIfPresent([TemplateEntry].self, forKey: .entries) ?? []
        // Migrate legacy ladder/emom to timed
        if let raw = try? c.decodeIfPresent(String.self, forKey: .workoutType) {
            workoutType = (raw == "ladder" || raw == "emom") ? .timed : (WorkoutType(rawValue: raw) ?? .strict)
        } else {
            workoutType = .strict
        }
        duration = try c.decodeIfPresent(Int.self, forKey: .duration)
    }
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
//
// Strict: sets = nil, reps = reps performed, weight/isDouble/offsetWeight = load
// Timed:  sets = rounds completed, reps = reps per round (from prescription), weight/isDouble/offsetWeight = load

struct LogSet: Identifiable, Codable, Equatable {
    let id: String
    var sets: Int?          // Timed only: rounds completed
    var reps: String?       // Strict: reps performed / Timed: reps per round
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

    init(
        id: String = UUID().uuidString,
        exerciseId: String,
        exerciseName: String,
        sets: [LogSet] = [LogSet()],
        note: String? = nil
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.sets = sets.isEmpty ? [LogSet()] : sets
        self.note = note
    }

    // MARK: - Helpers

    var totalReps: Int {
        sets.reduce(0) {
            $0 + (($1.sets ?? 1) * (Int($1.reps ?? "0") ?? 0))
        }
    }

    var totalVolume: Double {
        sets.reduce(0.0) { total, set in
            let reps = Double(set.reps ?? "0") ?? 0
            let base = Double(set.weight ?? "0") ?? 0
            let weight: Double
            if set.isDouble {
                weight = base * 2
            } else if let offset = set.offsetWeight, let offsetVal = Double(offset), !offset.isEmpty {
                weight = base + offsetVal
            } else {
                weight = base
            }
            return total + Double(set.sets ?? 1) * reps * weight
        }
    }

    mutating func addRow() {
        let last = sets.last ?? LogSet()
        sets.append(LogSet(
            sets: last.sets,
            reps: last.reps,
            weight: last.weight,
            isDouble: last.isDouble
        ))
    }

    mutating func removeRow(at index: Int) {
        guard sets.count > 1 else { return }
        sets.remove(at: index)
    }
}

// MARK: - Workout

struct Workout: Identifiable, Equatable {
    let id: String
    var name: String?
    var date: Date
    var blockId: String?
    var logs: [WorkoutLog]
    var workoutType: WorkoutType

    init(
        id: String = UUID().uuidString,
        name: String? = nil,
        date: Date = Date(),
        blockId: String? = nil,
        logs: [WorkoutLog] = [],
        workoutType: WorkoutType = .strict
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.blockId = blockId
        self.logs = logs
        self.workoutType = workoutType
    }
}

extension Workout: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, date, blockId, logs, workoutType
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        date = try c.decode(Date.self, forKey: .date)
        blockId = try c.decodeIfPresent(String.self, forKey: .blockId)
        logs = try c.decodeIfPresent([WorkoutLog].self, forKey: .logs) ?? []
        // Migrate legacy ladder/emom to timed
        if let raw = try? c.decodeIfPresent(String.self, forKey: .workoutType) {
            workoutType = (raw == "ladder" || raw == "emom") ? .timed : (WorkoutType(rawValue: raw) ?? .strict)
        } else {
            workoutType = .strict
        }
    }
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
