import SwiftUI

struct LogView: View {

    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    let workout: Workout

    @State private var date: Date = Date()
    @State private var values: [String: [TrackingType: String]] = [:]
    @State private var isSaving = false

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            Form {
                Section("Workout") {
                    Text(workout.name)
                        .font(Theme.Font.body)

                    DatePicker(
                        "Date",
                        selection: $date,
                        displayedComponents: .date
                    )
                }

                ForEach(workout.exercises) { exercise in
                    exerciseSection(exercise)
                }
            }
        }
        .navigationTitle("Log Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(isSaving)
            }
        }
    }

    // MARK: - Exercise Section

    private func exerciseSection(_ exercise: Exercise) -> some View {
        Section(exercise.name) {
            ForEach(exercise.trackingTypes, id: \.self) { type in
                TextField(
                    type.rawValue.capitalized,
                    text: binding(for: exercise.id, type: type)
                )
            }
        }
    }

    // MARK: - Bindings

    private func binding(
        for exerciseId: String,
        type: TrackingType
    ) -> Binding<String> {
        Binding(
            get: {
                values[exerciseId]?[type] ?? ""
            },
            set: {
                values[exerciseId, default: [:]][type] = $0
            }
        )
    }

    // MARK: - Save

    private func save() {
        isSaving = true

        let results: [ExerciseResult] = workout.exercises.map { exercise in
            ExerciseResult(
                exerciseId: exercise.id,
                values: values[exercise.id] ?? [:]
            )
        }

        let log = WorkoutLog(
            workoutId: workout.id,
            date: date,
            exerciseResults: results
        )

        Task {
            await appViewModel.saveWorkoutLog(log)
            isSaving = false
            dismiss()
        }
    }
}
