import SwiftUI

struct LogView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var selectedWorkout: Workout?
    @State private var exerciseValues: [String: String] = [:]
    @State private var logDate = Date()
    @State private var isSaving = false
    @State private var showingSaveConfirmation = false

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            if let block = appViewModel.activeBlock {
                if let workout = selectedWorkout {
                    logEntryView(block: block, workout: workout)
                } else {
                    workoutSelectionView(block: block)
                }
            } else {
                noBlockView
            }
        }
        .alert("Workout Logged", isPresented: $showingSaveConfirmation) {
            Button("OK") {
                resetForm()
            }
        } message: {
            Text("Your workout has been saved.")
        }
    }

    private func workoutSelectionView(block: Block) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            Text("Log Workout")
                .font(.system(size: Theme.TypeSize.xl, weight: .semibold))
                .foregroundColor(.brand.textPrimary)

            Text("Select a workout to log")
                .font(Theme.Font.body)
                .foregroundColor(.brand.textSecondary)

            ForEach(block.workouts) { workout in
                workoutButton(workout)
            }

            Spacer()
        }
        .padding(Theme.Space.md)
    }

    private func workoutButton(_ workout: Workout) -> some View {
        Button {
            selectWorkout(workout)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text("Workout \(workout.name)")
                        .font(Theme.Font.title)
                        .foregroundColor(.brand.textPrimary)

                    Text("\(workout.exercises.count) exercises")
                        .font(Theme.Font.meta)
                        .foregroundColor(.brand.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.brand.textSecondary)
            }
            .padding(Theme.Space.md)
            .background(Color.brand.surface)
            .cornerRadius(Theme.Radius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(Color.brand.border, lineWidth: 1)
            )
        }
    }

    private func logEntryView(block: Block, workout: Workout) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {
                    logHeader(workout: workout)
                    dateSection
                    exercisesSection(workout: workout)
                }
                .padding(Theme.Space.md)
            }

            saveButton(block: block, workout: workout)
        }
    }

    private func logHeader(workout: Workout) -> some View {
        HStack {
            Button {
                selectedWorkout = nil
            } label: {
                HStack(spacing: Theme.Space.xs) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(Theme.Font.body)
                .foregroundColor(.brand.primary)
            }

            Spacer()
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("Date")
                .font(Theme.Font.meta)
                .foregroundColor(.brand.textSecondary)

            DatePicker(
                "",
                selection: $logDate,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
        }
    }

    private func exercisesSection(workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text("Workout \(workout.name)")
                .font(Theme.Font.title)
                .foregroundColor(.brand.textPrimary)

            ForEach(workout.exercises) { exercise in
                exerciseInputRow(exercise)
            }
        }
    }

    private func exerciseInputRow(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(exercise.name)
                .font(Theme.Font.body)
                .foregroundColor(.brand.textPrimary)

            TextField(
                exercise.trackingType.placeholder,
                text: Binding(
                    get: { exerciseValues[exercise.id] ?? "" },
                    set: { exerciseValues[exercise.id] = $0 }
                )
            )
            .font(Theme.Font.body)
            .padding(Theme.Space.md)
            .background(Color.brand.surface)
            .cornerRadius(Theme.Radius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(Color.brand.border, lineWidth: 1)
            )

            if let lastLog = getLastValue(for: exercise.id) {
                Text("Last: \(lastLog)")
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

    private func saveButton(block: Block, workout: Workout) -> some View {
        Button {
            saveLog(block: block, workout: workout)
        } label: {
            Text(isSaving ? "Saving..." : "Save Workout")
                .font(Theme.Font.body)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(Theme.Space.md)
                .background(canSave ? Color.brand.primary : Color.brand.textSecondary)
                .cornerRadius(Theme.Radius.sm)
        }
        .disabled(!canSave || isSaving)
        .padding(Theme.Space.md)
        .background(Color.brand.background)
    }

    private var noBlockView: some View {
        VStack(spacing: Theme.Space.md) {
            Text("No active block")
                .font(Theme.Font.title)
                .foregroundColor(.brand.textPrimary)

            Text("Create a training block from the Home tab to start logging workouts.")
                .font(Theme.Font.body)
                .foregroundColor(.brand.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Space.xl)
    }

    private var canSave: Bool {
        exerciseValues.values.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func selectWorkout(_ workout: Workout) {
        selectedWorkout = workout

        if let lastLog = appViewModel.getLastLog(for: workout.id) {
            for result in lastLog.exerciseResults {
                exerciseValues[result.exerciseId] = result.value
            }
        } else {
            exerciseValues = [:]
        }
    }

    private func getLastValue(for exerciseId: String) -> String? {
        guard let workout = selectedWorkout,
              let lastLog = appViewModel.getLastLog(for: workout.id),
              let result = lastLog.exerciseResults.first(where: { $0.exerciseId == exerciseId })
        else { return nil }

        return result.value
    }

    private func saveLog(block: Block, workout: Workout) {
        guard let blockId = block.id else { return }

        isSaving = true

        let exerciseResults = workout.exercises.map { exercise in
            ExerciseResult(
                exerciseId: exercise.id,
                exerciseName: exercise.name,
                trackingType: exercise.trackingType,
                value: exerciseValues[exercise.id] ?? ""
            )
        }

        let log = WorkoutLog(
            userId: appViewModel.userId ?? "",
            blockId: blockId,
            workoutId: workout.id,
            workoutName: workout.name,
            date: logDate,
            exerciseResults: exerciseResults
        )

        Task {
            await appViewModel.saveLog(log)
            isSaving = false
            showingSaveConfirmation = true
        }
    }

    private func resetForm() {
        selectedWorkout = nil
        exerciseValues = [:]
        logDate = Date()
    }
}
