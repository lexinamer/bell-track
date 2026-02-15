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

    private var workoutText: String {

        guard let workoutCount else { return "" }

        return "\(workoutCount) workouts"
    }

    private var progressText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let start = formatter.string(from: block.startDate)

        if let endDate = block.endDate {
            let end = formatter.string(from: endDate)
            return "\(start) – \(end)"
        } else {
            return "Started \(start)"
        }
    }

    // MARK: - View

    var body: some View {

        HStack(spacing: 0) {

            // Purple accent bar
            Rectangle()
                .fill(ColorTheme.blockColor)
                .frame(width: 4)

            VStack(
                alignment: .leading,
                spacing: Theme.Space.xs
            ) {

                Text(block.name)
                    .font(Theme.Font.cardTitle)
                    .foregroundColor(Color.brand.textPrimary)
                    .lineLimit(1)

                Text(progressText)
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(Color.brand.textSecondary)

                if !workoutText.isEmpty {

                    Text(workoutText)
                        .font(Theme.Font.cardCaption)
                        .foregroundColor(Color.brand.textSecondary)
                }
            }
            .padding(Theme.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: Theme.Radius.md))
        .shadow(
            color: Color.black.opacity(0.25),
            radius: 8,
            x: 0,
            y: 2
        )
        .contentShape(Rectangle())
    }
}
