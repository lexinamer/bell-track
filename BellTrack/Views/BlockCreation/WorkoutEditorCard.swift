import SwiftUI

struct WorkoutEditorCard: View {
    @Binding var workout: Workout
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            HStack {
                Text("Workout \(workout.name)")
                    .font(Theme.Font.title)
                    .foregroundColor(.brand.textPrimary)

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.brand.textSecondary)
                }
            }

            ForEach(workout.exercises.indices, id: \.self) { index in
                ExerciseRow(
                    exercise: $workout.exercises[index],
                    onDelete: {
                        workout.exercises.remove(at: index)
                    }
                )
            }

            Button {
                workout.exercises.append(Exercise(name: "", trackingType: .weightReps))
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add Exercise")
                }
                .font(Theme.Font.meta)
                .foregroundColor(.brand.primary)
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
}

struct ExerciseRow: View {
    @Binding var exercise: Exercise
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack {
                TextField("Exercise name", text: $exercise.name)
                    .font(Theme.Font.body)
                    .foregroundColor(.brand.textPrimary)

                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.brand.textSecondary)
                }
            }

            TrackingTypePicker(selected: $exercise.trackingType)
        }
        .padding(Theme.Space.sm)
        .background(Color.brand.background)
        .cornerRadius(Theme.Radius.sm)
    }
}

struct TrackingTypePicker: View {
    @Binding var selected: TrackingType

    var body: some View {
        HStack(spacing: Theme.Space.xs) {
            ForEach(TrackingType.allCases) { type in
                Button {
                    selected = type
                } label: {
                    Text(shortLabel(for: type))
                        .font(Theme.Font.meta)
                        .foregroundColor(selected == type ? .white : .brand.textSecondary)
                        .padding(.horizontal, Theme.Space.sm)
                        .padding(.vertical, Theme.Space.xs)
                        .background(selected == type ? Color.brand.primary : Color.brand.surface)
                        .cornerRadius(Theme.Radius.sm)
                }
            }
        }
    }

    private func shortLabel(for type: TrackingType) -> String {
        switch type {
        case .weightReps: return "Wt×Rep"
        case .reps: return "Reps"
        case .time: return "Time"
        case .notes: return "Notes"
        }
    }
}
