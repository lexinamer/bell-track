import SwiftUI

// MARK: - Workout Management

extension TrainViewModel {

    // MARK: - Queries

    var activeBlockWorkouts: [Workout] {
        guard let block = activeBlock else { return [] }
        return workouts
            .filter { $0.blockId == block.id }
            .sorted { $0.date > $1.date }
    }

    var filteredWorkouts: [Workout] {
        if let blockId = selectedBlockId {
            return workouts
                .filter { $0.blockId == blockId }
                .sorted { $0.date > $1.date }
        }
        return workouts.sorted { $0.date > $1.date }
    }

    var displayWorkouts: [Workout] {
        var filtered = filteredWorkouts
        if let templateId = selectedTemplateId {
            let name = templates.first(where: { $0.id == templateId })?.name
            filtered = filtered.filter { $0.name == name }
        }
        return filtered
    }

    func recentWorkouts(for blockId: String, limit: Int) -> [Workout] {
        workouts
            .filter { $0.blockId == blockId }
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map { $0 }
    }

    func groupedWorkoutsByMonth(_ workouts: [Workout]) -> [(month: String, workouts: [Workout])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        let grouped = Dictionary(grouping: workouts) { formatter.string(from: $0.date) }
        return grouped
            .map { (month: $0.key, workouts: $0.value.sorted { $0.date > $1.date }) }
            .sorted {
                guard let d1 = formatter.date(from: $0.month),
                      let d2 = formatter.date(from: $1.month) else {
                    return $0.month > $1.month
                }
                return d1 > d2
            }
    }

    // MARK: - Filter

    func selectTemplate(_ templateId: String?) {
        selectedTemplateId = templateId
    }

    // MARK: - CRUD

    func saveWorkout(_ workout: Workout) async {
        do {
            try await firestore.saveWorkout(
                id: workout.id,
                name: workout.name,
                date: workout.date,
                blockId: workout.blockId,
                logs: workout.logs
            )
            await load()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to save workout:", error)
        }
    }

    func deleteWorkout(id: String) async {
        do {
            try await firestore.deleteWorkout(id: id)
            workouts.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to delete workout:", error)
        }
    }

    // MARK: - Stats

    func totalWorkouts(for blockId: String?) -> Int {
        blockId != nil
            ? workouts.filter { $0.blockId == blockId }.count
            : workouts.count
    }

    func totalSets(for blockId: String?) -> Int {
        let filtered = blockId != nil ? workouts.filter { $0.blockId == blockId } : workouts
        return filtered.reduce(0) { total, workout in
            total + workout.logs.reduce(0) { $0 + ($1.sets ?? 0) }
        }
    }

    func totalVolume(for blockId: String?) -> Double {
        let filtered = blockId != nil ? workouts.filter { $0.blockId == blockId } : workouts
        return filtered.reduce(0.0) { total, workout in
            total + workout.logs.reduce(0.0) { logTotal, log in
                let sets = Double(log.sets ?? 0)
                let reps = Double(log.reps ?? "0") ?? 0
                let baseWeight = Double(log.weight ?? "0") ?? 0
                let weight = log.isDouble ? baseWeight * 2 : baseWeight
                let mode = exerciseMap[log.exerciseId]?.mode ?? .reps
                return (weight > 0 && reps > 0 && mode != .time)
                    ? logTotal + (sets * reps * weight)
                    : logTotal
            }
        }
    }
}
