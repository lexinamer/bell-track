import SwiftUI

struct ExerciseDetailView: View {

    // MARK: - Identity

    private let itemId: String
    private let itemName: String
    private let primaryMuscles: [MuscleGroup]
    private let secondaryMuscles: [MuscleGroup]
    private let isComplex: Bool
    private let componentNames: String?

    // MARK: - State

    @State private var stats: ExerciseDetailStats?
    @State private var isLoading = true

    private let firestore = FirestoreService()

    // MARK: - Init (Exercise)

    init(exercise: Exercise) {
        self.itemId = exercise.id
        self.itemName = exercise.name
        self.primaryMuscles = exercise.primaryMuscles
        self.secondaryMuscles = exercise.secondaryMuscles
        self.isComplex = false
        self.componentNames = nil
    }

    // MARK: - Init (Complex)

    init(
        resolvedComplex: ResolvedComplex,
        exercises: [Exercise]
    ) {
        self.itemId = resolvedComplex.id
        self.itemName = resolvedComplex.name
        self.primaryMuscles = resolvedComplex.primaryMuscles
        self.secondaryMuscles = resolvedComplex.secondaryMuscles
        self.isComplex = true

        self.componentNames =
            exercises
                .filter { resolvedComplex.exerciseIds.contains($0.id) }
                .map { $0.name }
                .joined(separator: " + ")
    }

    // MARK: - View

    var body: some View {

        ZStack {

            Color.brand.background
                .ignoresSafeArea()

            if isLoading {

                ProgressView()

            } else if let stats {

                ScrollView {

                    LazyVStack(
                        alignment: .leading,
                        spacing: Theme.Space.lg
                    ) {

                        header

                        musclesSection(stats)

                        overviewSection(stats)

                        recordsSection(stats)
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
        .task {
            await load()
        }
    }

    // MARK: - Header

    private var header: some View {

        VStack(
            alignment: .leading,
            spacing: Theme.Space.xs
        ) {

            if let componentNames {

                Text(componentNames)
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Muscles

    private func musclesSection(
        _ stats: ExerciseDetailStats
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: Theme.Space.sm
        ) {

            Text("Muscles")
                .font(Theme.Font.sectionTitle)

            MuscleTagsView(
                primaryMuscles: stats.primaryMuscles,
                secondaryMuscles: stats.secondaryMuscles
            )
        }
    }

    // MARK: - Overview

    private func overviewSection(
        _ stats: ExerciseDetailStats
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: Theme.Space.sm
        ) {

            Text("Overview")
                .font(Theme.Font.sectionTitle)

            HStack(
                spacing: Theme.Space.sm
            ) {

                statCard(
                    value: "\(stats.totalWorkouts)",
                    label: "Workouts"
                )

                statCard(
                    value: "\(stats.totalSets)",
                    label: "Total Sets"
                )
            }
        }
    }

    // MARK: - Records

    private func recordsSection(
        _ stats: ExerciseDetailStats
    ) -> some View {

        let hasRecords =
            stats.heaviestWeight != nil
            || stats.mostSets != nil
            || stats.mostReps != nil

        guard hasRecords else { return AnyView(EmptyView()) }

        return AnyView(

            VStack(
                alignment: .leading,
                spacing: Theme.Space.sm
            ) {

                Text("Personal Records")
                    .font(Theme.Font.sectionTitle)

                HStack(
                    spacing: Theme.Space.sm
                ) {

                    if let hw = stats.heaviestWeight {

                        recordCard(
                            value: "\(hw)kg",
                            label: "Heaviest"
                        )
                    }

                    if let ms = stats.mostSets {

                        recordCard(
                            value: "\(ms)",
                            label: "Most Sets"
                        )
                    }

                    if let mr = stats.mostReps {

                        recordCard(
                            value: mr,
                            label: "Most Reps"
                        )
                    }
                }
            }
        )
    }

    // MARK: - Stat Card

    private func statCard(
        value: String,
        label: String
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: Theme.Space.xs
        ) {

            Text(value)
                .font(Theme.Font.pageTitle)

            Text(label)
                .font(Theme.Font.cardCaption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(Theme.Radius.md)
    }

    // MARK: - Record Card

    private func recordCard(
        value: String,
        label: String
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: Theme.Space.xs
        ) {

            Text(value)
                .font(Theme.Font.cardTitle)
                .foregroundColor(Color.brand.primary)

            Text(label)
                .font(Theme.Font.cardCaption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.brand.primary.opacity(0.08))
        .cornerRadius(Theme.Radius.md)
    }

    // MARK: - Empty State

    private var emptyState: some View {

        VStack(
            spacing: Theme.Space.md
        ) {

            Text("No workout data yet")
                .font(Theme.Font.cardTitle)

            Text("Stats will appear after logging workouts.")
                .font(Theme.Font.cardSecondary)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Load

    private func load() async {

        do {

            let workouts =
                try await firestore.fetchWorkouts()

            let filtered =
                workouts.filter { workout in
                    workout.logs.contains {
                        $0.exerciseId == itemId
                        && $0.isComplex == isComplex
                    }
                }

            let logs =
                filtered.flatMap { workout in
                    workout.logs.filter {
                        $0.exerciseId == itemId
                        && $0.isComplex == isComplex
                    }
                }

            stats = computeStats(
                workouts: filtered,
                logs: logs
            )

            isLoading = false

        } catch {

            print(error)
            isLoading = false
        }
    }

    // MARK: - Stats Logic

    private func computeStats(
        workouts: [Workout],
        logs: [WorkoutLog]
    ) -> ExerciseDetailStats {

        let weights =
            logs.compactMap { Double($0.weight ?? "") }

        let reps =
            logs.compactMap { Int($0.reps ?? "") }

        return ExerciseDetailStats(
            totalWorkouts: workouts.count,
            totalSets: logs.compactMap { $0.sets }.reduce(0,+),
            heaviestWeight: weights.max().map { "\($0)" },
            mostSets: logs.compactMap { $0.sets }.max(),
            mostReps: reps.max().map { "\($0)" },
            primaryMuscles: primaryMuscles,
            secondaryMuscles: secondaryMuscles
        )
    }
}
