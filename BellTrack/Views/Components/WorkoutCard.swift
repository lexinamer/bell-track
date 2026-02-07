import SwiftUI

struct WorkoutCard: View {

    let workout: Workout
    let isExpanded: Bool

    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    let dateBadgeColor: Color
    let title: String
    let exerciseCountText: String
    let logs: [WorkoutLog]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: - Main card content
            HStack(alignment: .top, spacing: Theme.Space.md) {

                // Date badge
                VStack(spacing: 2) {
                    Text(workout.date.formatted(.dateTime.day(.defaultDigits)))
                        .font(Theme.Font.navigationTitle)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Text(workout.date.formatted(.dateTime.month(.abbreviated)))
                        .font(Theme.Font.cardCaption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .frame(width: 50, height: 50)
                .background(dateBadgeColor)
                .cornerRadius(8)

                // Workout details
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text(title)
                        .font(Theme.Font.cardTitle)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(exerciseCountText)
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture {
                onToggle()
            }

            // MARK: - Expanded exercise details
            if isExpanded {
                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    ForEach(logs, id: \.id) { log in
                        exerciseRow(log)
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.3))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }

            Button(action: onDuplicate) {
                Label("Duplicate", systemImage: "doc.on.doc")
            }

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        }
    }

    // MARK: - Exercise Row

    private func exerciseRow(_ log: WorkoutLog) -> some View {
        HStack {
            Text(formatExerciseDetails(log))
                .font(Theme.Font.cardSecondary)
                .foregroundColor(.primary)
            Spacer()
        }
    }

    // MARK: - Formatting

    private func formatExerciseDetails(_ log: WorkoutLog) -> String {
        var components: [String] = []
        components.append(log.exerciseName)

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
