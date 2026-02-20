import SwiftUI

struct BlockCard: View {

    enum CardState {
        case active(weekProgress: String, endDate: String)
        case upcoming(startDate: String)
        case completed(dateRange: String)
    }

    let block: Block
    let state: CardState
    let blockIndex: Int
    let onTap: () -> Void

    // MARK: - Derived

    private var subtitle: String {
        switch state {
        case .active(let weekProgress, let endDate):
            return "\(weekProgress) · Ends \(endDate)"
        case .upcoming(let startDate):
            return "Starts \(startDate)"
        case .completed(let dateRange):
            return dateRange
        }
    }

    private var accentColor: Color {
        BlockColorPalette.blockPrimary(blockIndex: blockIndex)
    }

    // MARK: - Body

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text(block.name)
                        .font(Theme.Font.sectionTitle)
                        .foregroundColor(Color.brand.textPrimary)

                    Text(subtitle)
                        .font(Theme.Font.cardCaption)
                        .foregroundColor(Color.brand.textSecondary)
                }
                .padding(Theme.Space.md)

                Spacer()
            }
            .background(Color.brand.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
        .buttonStyle(.plain)
    }
}
