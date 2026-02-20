import SwiftUI

struct ExerciseDetailView: View {

    private let itemId: String
    private let itemName: String
    private let primaryMuscles: [MuscleGroup]
    private let secondaryMuscles: [MuscleGroup]
    private let componentNames: String?

    @State private var stats: ExerciseDetailStats?
    @State private var isLoading = true

    private let firestore = FirestoreService.shared

    init(exercise: Exercise) {
        self.itemId = exercise.id
        self.itemName = exercise.name
        self.primaryMuscles = exercise.primaryMuscles
        self.secondaryMuscles = exercise.secondaryMuscles
        self.componentNames = nil
    }

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            if isLoading {
                ProgressView()
            } else if let stats {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Space.lg) {
                        header
                        musclesSection(stats)
                        overviewSection(stats)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, Theme.Space.sm)
                }
            } else {
                emptyState
            }
        }
        .navigationTitle(itemName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            if let componentNames {
                Text(componentNames)
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func musclesSection(_ stats: ExerciseDetailStats) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("Muscles")
                .font(Theme.Font.sectionTitle)
            ExerciseChips(
                primaryMuscles: stats.primaryMuscles,
                secondaryMuscles: stats.secondaryMuscles
            )
        }
    }

    private func overviewSection(_ stats: ExerciseDetailStats) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("Overview")
                .font(Theme.Font.sectionTitle)

            HStack(spacing: Theme.Space.sm) {
                statCard(value: "\(stats.totalWorkouts)", label: "Workouts")
                statCard(value: "\(stats.totalReps)", label: "Total Reps")
                if let hw = stats.heaviestWeight {
                    statCard(value: hw, label: "Heaviest")
                }
            }
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(value)
                .font(Theme.Font.pageTitle)
            Text(label)
                .font(Theme.Font.cardCaption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.brand.surface)
        .cornerRadius(Theme.Radius.md)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Space.md) {
            Text("No workout data yet")
                .font(Theme.Font.cardTitle)
            Text("Stats will appear after logging workouts.")
                .font(Theme.Font.cardSecondary)
                .foregroundColor(.secondary)
        }
    }

    private func load() async {
        do {
            let workouts = try await firestore.fetchWorkouts()
            let filtered = workouts.filter { workout in
                workout.logs.contains { $0.exerciseId == itemId }
            }
            let logs = filtered.flatMap { workout in
                workout.logs.filter { $0.exerciseId == itemId }
            }
            stats = computeStats(workouts: filtered, logs: logs)
            isLoading = false
        } catch {
            print(error)
            isLoading = false
        }
    }

    private func computeStats(workouts: [Workout], logs: [WorkoutLog]) -> ExerciseDetailStats {
        let allSets = logs.flatMap { $0.sets }
        let weights = allSets.compactMap { Double($0.weight ?? "") }
        let heaviest: String? = weights.max().map { w in
            w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))kg" : "\(w)kg"
        }

        return ExerciseDetailStats(
            totalWorkouts: workouts.count,
            totalReps: logs.reduce(0) { $0 + $1.totalReps },
            heaviestWeight: heaviest,
            mostSets: logs.map { $0.sets.count }.max(),
            mostReps: logs.map { $0.totalReps }.max().map { "\($0)" },
            primaryMuscles: primaryMuscles,
            secondaryMuscles: secondaryMuscles
        )
    }
}
