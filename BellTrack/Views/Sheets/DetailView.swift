import SwiftUI

// Exercise Detail View - shows exercise history across all workouts
struct DetailView: View {
    let exercise: Exercise

    @Environment(\.dismiss) private var dismiss

    @State private var exerciseEntries: [(date: Date, details: String, note: String?)] = []
    @State private var exerciseStats: ExerciseDetailStats?
    @State private var isLoading = true

    private let firestore = FirestoreService()

    init(exercise: Exercise) {
        self.exercise = exercise
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    VStack(spacing: Theme.Space.md) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading...")
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else if exerciseEntries.isEmpty {
                    VStack(spacing: Theme.Space.md) {
                        Text("No workouts found")
                            .font(Theme.Font.cardTitle)
                            .foregroundColor(.secondary)

                        Text("No workouts found with this exercise.")
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    LazyVStack(alignment: .leading, spacing: Theme.Space.mdp) {
                        // Stats header
                        if let stats = exerciseStats {
                            exerciseStatsHeader(stats)
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Exercise Stats Header

    private func exerciseStatsHeader(_ stats: ExerciseDetailStats) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            // Muscle tags
            if !stats.primaryMuscles.isEmpty || !stats.secondaryMuscles.isEmpty {
                let allMuscles: [(muscle: MuscleGroup, isPrimary: Bool)] =
                    stats.primaryMuscles.map { ($0, true) } +
                    stats.secondaryMuscles.map { ($0, false) }

                FlowLayout(spacing: 6) {
                    ForEach(Array(allMuscles.enumerated()), id: \.offset) { _, item in
                        Text(item.muscle.displayName)
                            .font(Theme.Font.cardCaption)
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                item.isPrimary
                                    ? Color.brand.primary
                                    : Color.brand.primary.opacity(0.55)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
            }

            // Stat boxes row
            HStack(spacing: Theme.Space.sm) {
                statBox(value: "\(stats.totalWorkouts)", label: "Workouts")
                statBox(value: "\(stats.totalSets)", label: "Total Sets")
            }

            // Personal Records
            let hasRecords = stats.heaviestWeight != nil || stats.mostSets != nil || stats.mostReps != nil
            if hasRecords {
                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    Text("Personal Records")
                        .font(Theme.Font.cardTitle)
                        .fontWeight(.bold)

                    HStack(spacing: Theme.Space.sm) {
                        if let hw = stats.heaviestWeight {
                            recordBox(value: "\(hw)kg", label: "Heaviest")
                        }
                        if let ms = stats.mostSets {
                            recordBox(value: "\(ms)", label: "Most Sets")
                        }
                        if let mr = stats.mostReps {
                            recordBox(value: mr, label: "Most Reps")
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Stat Box

    private func statBox(value: String, label: String) -> some View {
        VStack(spacing: Theme.Space.xs) {
            Text(value)
                .font(Theme.Font.navigationTitle)
                .fontWeight(.bold)
            Text(label)
                .font(Theme.Font.cardCaption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: - Record Box

    private func recordBox(value: String, label: String) -> some View {
        VStack(spacing: Theme.Space.xs) {
            Text(value)
                .font(Theme.Font.cardTitle)
                .fontWeight(.semibold)
                .foregroundColor(Color.brand.primary)
            Text(label)
                .font(Theme.Font.cardCaption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.brand.primary.opacity(0.05))
        .cornerRadius(8)
    }


    // MARK: - Load Data

    private func loadData() async {
        do {
            let workouts = try await firestore.fetchWorkouts()

            // Filter workouts containing this exercise
            let filteredWorkouts = workouts.filter { workout in
                workout.logs.contains { $0.exerciseId == exercise.id }
            }

            // Build exercise entries
            var entries: [(date: Date, details: String, note: String?)] = []
            var allLogs: [WorkoutLog] = []

            for workout in filteredWorkouts {
                for log in workout.logs where log.exerciseId == exercise.id {
                    entries.append((date: workout.date, details: formatWorkoutDetails(log), note: log.note))
                    allLogs.append(log)
                }
            }

            entries.sort { $0.date > $1.date }
            self.exerciseEntries = entries

            // Compute exercise stats
            self.exerciseStats = computeExerciseStats(
                workouts: filteredWorkouts,
                logs: allLogs
            )

            self.isLoading = false

        } catch {
            print("Failed to load exercise data:", error)
            self.isLoading = false
        }
    }

    // MARK: - Compute Exercise Stats

    private func computeExerciseStats(
        workouts: [Workout],
        logs: [WorkoutLog]
    ) -> ExerciseDetailStats {
        let totalWorkouts = workouts.count
        let totalSets = logs.compactMap { $0.sets }.reduce(0, +)

        // Personal records
        let weights = logs.compactMap { $0.weight }.compactMap { Double($0) }
        let heaviestWeight = weights.max().map { String(format: "%g", $0) }

        let mostSets = logs.compactMap { $0.sets }.max()

        let repsAsInts = logs.compactMap { $0.reps }.compactMap { Int($0) }
        let mostReps = repsAsInts.max().map { String($0) }

        return ExerciseDetailStats(
            totalWorkouts: totalWorkouts,
            totalSets: totalSets,
            heaviestWeight: heaviestWeight,
            mostSets: mostSets,
            mostReps: mostReps,
            primaryMuscles: exercise.primaryMuscles,
            secondaryMuscles: exercise.secondaryMuscles
        )
    }

    // MARK: - Format Details

    private func formatWorkoutDetails(_ log: WorkoutLog) -> String {
        var components: [String] = []

        if let sets = log.sets, sets > 0 {
            if let reps = log.reps, !reps.isEmpty {
                components.append("\(sets)x\(reps)")
            } else {
                components.append("\(sets) sets")
            }
        }

        if let weight = log.weight, !weight.isEmpty {
            components.append("\(weight)kg")
        }

        if let note = log.note, !note.isEmpty {
            components.append(note)
        }

        return components.joined(separator: " • ")
    }
}
