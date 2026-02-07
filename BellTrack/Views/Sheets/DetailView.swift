import SwiftUI

struct DetailView: View {

    // The item being shown (exercise or complex)
    private let itemId: String
    private let itemName: String
    private let primaryMuscles: [MuscleGroup]
    private let secondaryMuscles: [MuscleGroup]
    private let isComplex: Bool
    private let componentNames: String?

    @Environment(\.dismiss) private var dismiss

    @State private var exerciseStats: ExerciseDetailStats?
    @State private var isLoading = true

    private let firestore = FirestoreService()

    // Init for Exercise
    init(exercise: Exercise) {
        self.itemId = exercise.id
        self.itemName = exercise.name
        self.primaryMuscles = exercise.primaryMuscles
        self.secondaryMuscles = exercise.secondaryMuscles
        self.isComplex = false
        self.componentNames = nil
    }

    // Init for ResolvedComplex
    init(resolvedComplex: ResolvedComplex, exercises: [Exercise]) {
        self.itemId = resolvedComplex.id
        self.itemName = resolvedComplex.name
        self.primaryMuscles = resolvedComplex.primaryMuscles
        self.secondaryMuscles = resolvedComplex.secondaryMuscles
        self.isComplex = true
        self.componentNames = exercises
            .filter { resolvedComplex.exerciseIds.contains($0.id) }
            .map { $0.name }
            .joined(separator: " + ")
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
                } else if let stats = exerciseStats {
                    LazyVStack(alignment: .leading, spacing: Theme.Space.mdp) {
                        exerciseStatsHeader(stats)
                    }
                    .padding(.vertical, 20)
                } else {
                    VStack(spacing: Theme.Space.md) {
                        Text("No workouts found")
                            .font(Theme.Font.cardTitle)
                            .foregroundColor(.secondary)

                        Text("No workouts found with this \(isComplex ? "complex" : "exercise").")
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .navigationTitle(itemName)
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
            // Component names for complexes
            if let names = componentNames {
                Text(names)
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(.secondary)
            }

            // Muscle tags
            MuscleTagsView(
                primaryMuscles: stats.primaryMuscles,
                secondaryMuscles: stats.secondaryMuscles,
                spacing: 6,
                tagPadding: (10, 4),
                cornerRadius: 12
            )

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

            let filteredWorkouts = workouts.filter { workout in
                workout.logs.contains {
                    $0.exerciseId == itemId && $0.isComplex == isComplex
                }
            }

            var allLogs: [WorkoutLog] = []
            for workout in filteredWorkouts {
                for log in workout.logs where log.exerciseId == itemId && log.isComplex == isComplex {
                    allLogs.append(log)
                }
            }

            self.exerciseStats = computeStats(
                workouts: filteredWorkouts,
                logs: allLogs
            )
            self.isLoading = false

        } catch {
            print("Failed to load detail data:", error)
            self.isLoading = false
        }
    }

    // MARK: - Compute Stats

    private func computeStats(
        workouts: [Workout],
        logs: [WorkoutLog]
    ) -> ExerciseDetailStats {
        let totalWorkouts = workouts.count
        let totalSets = logs.compactMap { $0.sets }.reduce(0, +)

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
            primaryMuscles: primaryMuscles,
            secondaryMuscles: secondaryMuscles
        )
    }
}
