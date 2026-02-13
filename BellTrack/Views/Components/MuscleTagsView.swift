import SwiftUI

struct MuscleTagsView: View {
    let primaryMuscles: [MuscleGroup]
    let secondaryMuscles: [MuscleGroup]
    var spacing: CGFloat = Theme.Space.xs
    var tagPadding: (horizontal: CGFloat, vertical: CGFloat) = (8, 3)
    var cornerRadius: CGFloat = 10
    var font: Font = Theme.Font.cardCaption

    private var allMuscles: [(muscle: MuscleGroup, isPrimary: Bool)] {
        primaryMuscles.map { ($0, true) } +
        secondaryMuscles.map { ($0, false) }
    }

    var body: some View {
        if !allMuscles.isEmpty {
            FlowLayout(spacing: spacing) {
                ForEach(Array(allMuscles.enumerated()), id: \.offset) { _, item in
                    Text(item.muscle.displayName)
                        .font(font)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, tagPadding.horizontal)
                        .padding(.vertical, tagPadding.vertical)
                        .background(
                            item.isPrimary
                                ? Color.brand.primary
                                : Color.brand.primary.opacity(0.55)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(cornerRadius)
                }
            }
        }
    }
}
