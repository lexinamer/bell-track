import SwiftUI

struct ExerciseChips: View {

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
            FlowLayout(
                horizontalSpacing: Theme.Space.xs,
                verticalSpacing: Theme.Space.sm
            ) {
                ForEach(Array(allMuscles.enumerated()), id: \.offset) { _, item in
                    Text(item.muscle.displayName)
                        .font(font)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, tagPadding.horizontal)
                        .padding(.vertical, tagPadding.vertical)
                        .background(
                            item.isPrimary
                            ? Color.brand.primary.opacity(0.7)
                            : Color.brand.primary.opacity(0.4)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(cornerRadius)
                }
            }
        }
    }
}

// MARK: - Private FlowLayout (only used by MuscleTags)

private struct FlowLayout: Layout {

    var horizontalSpacing: CGFloat = Theme.Space.xs
    var verticalSpacing: CGFloat = Theme.Space.sm   // bigger for row separation

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = arrange(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(
                    x: bounds.minX + position.x,
                    y: bounds.minY + position.y
                ),
                proposal: .unspecified
            )
        }
    }

    private func arrange(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> (positions: [CGPoint], size: CGSize) {

        let maxWidth = proposal.width ?? .infinity

        var positions: [CGPoint] = []

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {

            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))

            rowHeight = max(rowHeight, size.height)

            x += size.width + horizontalSpacing
            maxX = max(maxX, x - horizontalSpacing)
        }

        return (
            positions,
            CGSize(width: maxX, height: y + rowHeight)
        )
    }
}
