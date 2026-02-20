import SwiftUI

struct ExerciseCard: View {

    let exercise: Exercise
    let accentColor: Color

    let onTap: (() -> Void)?
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {

            HStack(alignment: .center, spacing: Theme.Space.md) {

                VStack(alignment: .leading, spacing: Theme.Space.sm) {

                    Text(exercise.name)
                        .font(Theme.Font.sectionTitle)
                        .foregroundColor(Color.brand.textPrimary)

                    ExerciseChips(
                        primaryMuscles: exercise.primaryMuscles,
                        secondaryMuscles: exercise.secondaryMuscles
                    )
                }

                Spacer()
            }
            .padding(Theme.Space.md)
        }
        .background(Color.brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .contentShape(Rectangle())

        // Tap → open detail
        .onTapGesture {
            onTap?()
        }

        // Long press → edit / delete
        .contextMenu {

            if let onEdit {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }

            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}
