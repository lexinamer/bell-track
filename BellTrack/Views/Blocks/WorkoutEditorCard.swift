import SwiftUI

struct WorkoutEditorCard: View {

    @Binding var workout: Workout

    @State private var newExerciseName: String = ""
    @State private var selectedTrackingTypes: Set<TrackingType> = []

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {

            // Workout name
            TextField("Workout name", text: $workout.name)
                .font(Theme.Font.body)
                .padding(Theme.Space.sm)
                .background(Color.brand.surface)
                .cornerRadius(Theme.Radius.sm)

            Divider()

            // Existing exercises
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                ForEach(workout.exercises) { exercise in
                    exerciseRow(exercise)
                }
            }

            Divider()

            // New exercise editor
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Text("Add Exercise")
                    .font(Theme.Font.meta)
                    .foregroundColor(.brand.textSecondary)

                TextField("Exercise name", text: $newExerciseName)
                    .font(Theme.Font.body)
                    .padding(Theme.Space.sm)
                    .background(Color.brand.surface)
                    .cornerRadius(Theme.Radius.sm)

                trackingTypeSelector

                Button("Add Exercise") {
                    addExercise()
                }
                .disabled(newExerciseName.isEmpty || selectedTrackingTypes.isEmpty)
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

    // MARK: - Subviews

    private func exerciseRow(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.name)
                .font(Theme.Font.body)
                .foregroundColor(.brand.textPrimary)

            Text(exercise.trackingTypes.map { $0.rawValue.capitalized }.joined(separator: ", "))
                .font(Theme.Font.meta)
                .foregroundColor(.brand.textSecondary)
        }
    }

    private var trackingTypeSelector: some View {
        HStack {
            ForEach(TrackingType.allCases, id: \.self) { type in
                Button {
                    toggleTrackingType(type)
                } label: {
                    Text(type.rawValue.capitalized)
                        .font(.caption)
                        .padding(6)
                        .background(
                            selectedTrackingTypes.contains(type)
                            ? Color.brand.primary.opacity(0.2)
                            : Color.clear
                        )
                        .cornerRadius(6)
                }
            }
        }
    }

    // MARK: - Actions

    private func toggleTrackingType(_ type: TrackingType) {
        if selectedTrackingTypes.contains(type) {
            selectedTrackingTypes.remove(type)
        } else {
            selectedTrackingTypes.insert(type)
        }
    }

    private func addExercise() {
        let exercise = Exercise(
            id: UUID().uuidString,
            name: newExerciseName,
            trackingTypes: Array(selectedTrackingTypes)
        )

        workout.exercises.append(exercise)
        newExerciseName = ""
        selectedTrackingTypes.removeAll()
    }
}
