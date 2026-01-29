import SwiftUI

struct WorkoutsView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    let block: Block

    @State private var selectedWorkout: Workout?
    @State private var showingLogSheet = false

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            if workouts.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: Theme.Space.md) {
                        ForEach(workouts) { workout in
                            workoutCard(workout)
                        }
                    }
                    .padding(Theme.Space.md)
                }
            }
        }
        .navigationTitle("Workouts")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedWorkout) { workout in
            LogView(workout: workout)
        }
    }

    // MARK: - Derived Data

    private var workouts: [Workout] {
        appViewModel.workouts(for: block)
    }

    private func logs(for workout: Workout) -> [WorkoutLog] {
        appViewModel.workoutLogs
            .filter { $0.workoutId == workout.id }
            .sorted { $0.date > $1.date }
    }

    // MARK: - UI

    private func workoutCard(_ workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {

            HStack {
                Text(workout.name)
                    .font(Theme.Font.title)
                    .foregroundColor(.brand.textPrimary)

                Spacer()

                Button {
                    selectedWorkout = workout
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.brand.primary)
                        .font(.title2)
                }
            }

            if let lastLog = logs(for: workout).first {
                lastLogView(lastLog, workout: workout)
            } else {
                Text("No workouts logged yet")
                    .font(Theme.Font.meta)
                    .foregroundColor(.brand.textSecondary)
            }
        }
        .padding(Theme.Space.md)
        .background(Color.brand.surface)
        .cornerRadius(Theme.Radius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(Color.brand.border, lineWidth: 1)
        )
    }

    private func lastLogView(
        _ log: WorkoutLog,
        workout: Workout
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text("Last logged: \(log.date.formatted(date: .abbreviated, time: .omitted))")
                .font(Theme.Font.meta)
                .foregroundColor(.brand.textSecondary)

            ForEach(workout.exercises) { exercise in
                exerciseRow(exercise, log: log)
            }
        }
    }

    private func exerciseRow(
        _ exercise: Exercise,
        log: WorkoutLog
    ) -> some View {
        let result = log.exerciseResults.first {
            $0.exerciseId == exercise.id
        }

        return HStack {
            Text(exercise.name)
                .font(Theme.Font.meta)
                .foregroundColor(.brand.textPrimary)

            Spacer()

            if let result {
                Text(displayValue(for: result))
                    .font(Theme.Font.meta)
                    .foregroundColor(.brand.textSecondary)
            } else {
                Text("—")
                    .font(Theme.Font.meta)
                    .foregroundColor(.brand.textSecondary)
            }
        }
    }

    private func displayValue(for result: ExerciseResult) -> String {
        result.values
            .map { key, value in
                "\(value)"
            }
            .joined(separator: " · ")
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Space.lg) {
            Text("No workouts")
                .font(Theme.Font.title)
                .foregroundColor(.brand.textPrimary)

            Text("Add workouts to this block to begin.")
                .font(Theme.Font.body)
                .foregroundColor(.brand.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Space.xl)
    }
}
