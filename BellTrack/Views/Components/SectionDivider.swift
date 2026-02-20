import SwiftUI

struct SectionDivider: View {

    let title: String
    var horizontalPadding: CGFloat = Theme.Space.md
    var verticalPadding: CGFloat = Theme.Space.md

    var body: some View {
        HStack(spacing: Theme.Space.sm) {

            Rectangle()
                .fill(Color.brand.textSecondary.opacity(0.2))
                .frame(height: 1)

            Text(title)
                .font(Theme.Font.cardCaption)
                .foregroundColor(Color.brand.textSecondary)
                .fixedSize()

            Rectangle()
                .fill(Color.brand.textSecondary.opacity(0.2))
                .frame(height: 1)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
    }
}
