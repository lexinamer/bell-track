import SwiftUI
import Combine

@MainActor
final class WorkoutsViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var workouts: [Workout] = []

    /// Maps blockId → colorIndex
    @Published private(set) var blockColors: [String: Int] = [:]

    @Published private(set) var isLoading: Bool = false

    private let firestore = FirestoreService()

    // MARK: - Load

    func load() async {

        isLoading = true
        defer { isLoading = false }

        do {

            async let fetchedWorkouts = firestore.fetchWorkouts()
            async let fetchedBlocks = firestore.fetchBlocks()

            let workoutsResult = try await fetchedWorkouts
            let blocksResult = try await fetchedBlocks

            self.workouts = workoutsResult.sorted {
                $0.date > $1.date
            }

            self.blockColors = Dictionary(
                uniqueKeysWithValues:
                    blocksResult.compactMap {
                        guard let colorIndex = $0.colorIndex else {
                            return nil
                        }
                        return ($0.id, colorIndex)
                    }
            )

        } catch {

            print("❌ Failed to load workouts:", error)
        }
    }

    // MARK: - Accessors

    /// Returns workouts sorted newest first
    var sortedWorkouts: [Workout] {
        workouts.sorted { $0.date > $1.date }
    }

    /// Returns workouts belonging to a block
    func workouts(for blockId: String) -> [Workout] {

        workouts
            .filter { $0.blockId == blockId }
            .sorted { $0.date > $1.date }
    }

    /// Returns badge color for a workout
    func badgeColor(for workout: Workout) -> Color {

        if let blockId = workout.blockId,
           let colorIndex = blockColors[blockId] {

            return ColorTheme.blockColor(for: colorIndex)
        }

        return ColorTheme.unassignedWorkoutColor
    }

    // MARK: - Duplication

    func duplicate(_ workout: Workout) -> Workout {

        Workout(
            id: UUID().uuidString,
            name: workout.name,
            date: Date(),
            blockId: workout.blockId,
            logs: workout.logs.map {

                WorkoutLog(
                    id: UUID().uuidString,
                    exerciseId: $0.exerciseId,
                    exerciseName: $0.exerciseName,
                    isComplex: $0.isComplex,
                    sets: $0.sets,
                    reps: $0.reps,
                    weight: $0.weight,
                    note: $0.note
                )
            }
        )
    }

    // MARK: - Save

    func save(_ workout: Workout) async {

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

            print("❌ Failed to save workout:", error)
        }
    }


    // MARK: - Delete

    func deleteWorkout(id: String) async {

        do {

            try await firestore.deleteWorkout(id: id)

            workouts.removeAll { $0.id == id }

        } catch {

            print("❌ Failed to delete workout:", error)
        }
    }

    // MARK: - Local Mutations (optional helpers)

    func insertLocal(_ workout: Workout) {

        workouts.insert(workout, at: 0)
    }

    func updateLocal(_ workout: Workout) {

        guard let index = workouts.firstIndex(where: { $0.id == workout.id }) else {
            return
        }

        workouts[index] = workout
    }

    func removeLocal(id: String) {

        workouts.removeAll { $0.id == id }
    }
}
