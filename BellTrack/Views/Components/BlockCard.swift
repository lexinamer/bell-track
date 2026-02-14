import SwiftUI

struct BlockCard: View {

    let block: Block
    let workoutCount: Int?
    let templateCount: Int?

    // MARK: - Init

    init(
        block: Block,
        workoutCount: Int? = nil,
        templateCount: Int? = nil
    ) {
        self.block = block
        self.workoutCount = workoutCount
        self.templateCount = templateCount
    }

    // MARK: - Derived

    private var blockColor: Color {
        ColorTheme.blockColor(for: block.colorIndex)
    }

    private var workoutText: String {

        guard let workoutCount else { return "" }

        return "\(workoutCount) workouts"
    }

    private var progressText: String {

        switch block.type {

        case .ongoing:

            let weeks =
                Calendar.current.dateComponents(
                    [.weekOfYear],
                    from: block.startDate,
                    to: Date()
                ).weekOfYear ?? 0

            return "Week \(max(1, weeks + 1)) (ongoing)"

        case .duration:

            guard let duration = block.durationWeeks else {
                return ""
            }

            let weeks =
                Calendar.current.dateComponents(
                    [.weekOfYear],
                    from: block.startDate,
                    to: Date()
                ).weekOfYear ?? 0

            let current =
                min(max(1, weeks + 1), duration)

            return "Week \(current) of \(duration)"
        }
    }

    // MARK: - View

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: Theme.Space.xs
        ) {

            Text(block.name)
                .font(Theme.Font.cardTitle)
                .foregroundColor(.white)
                .lineLimit(1)

            Text(progressText)
                .font(Theme.Font.cardCaption)
                .foregroundColor(.white.opacity(0.9))

            if !workoutText.isEmpty {

                Text(workoutText)
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(Theme.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(blockColor)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: Theme.Radius.md))
        .shadow(
            color: blockColor.opacity(0.25),
            radius: 6,
            x: 0,
            y: 3
        )
        .contentShape(Rectangle())
    }
}
