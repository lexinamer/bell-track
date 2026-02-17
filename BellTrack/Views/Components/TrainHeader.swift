import SwiftUI

struct TrainHeader: View {
    let blockName: String
    let isCompleted: Bool
    let showCompletedBadge: Bool
    let onTap: (() -> Void)?

    init(
        blockName: String,
        isCompleted: Bool = false,
        showCompletedBadge: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.blockName = blockName
        self.isCompleted = isCompleted
        self.showCompletedBadge = showCompletedBadge
        self.onTap = onTap
    }

    var body: some View {
        HStack {
            if let onTap = onTap {
                Button {
                    onTap()
                } label: {
                    headerContent
                }
                .buttonStyle(.plain)
            } else {
                headerContent
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color.brand.background)
    }

    private var headerContent: some View {
        HStack(spacing: 8) {
            Text(blockName)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(Color.brand.textPrimary)

            if showCompletedBadge {
                Text("COMPLETED")
                    .font(Theme.Font.statLabel)
                    .foregroundColor(Color.brand.textSecondary)
                    .padding(.horizontal, Theme.Space.sm)
                    .padding(.vertical, 2)
                    .background(Color.brand.surface)
                    .cornerRadius(Theme.Radius.xs)
            }

            if onTap != nil {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.brand.textPrimary)
            }
        }
    }
}
