import SwiftUI

struct BlockStats: View {
    let bestVolume: Int
    let lastVolume: Int

    var body: some View {
        HStack(spacing: Theme.Space.lg) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Best")
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(Color.brand.textSecondary)
                Text("\(bestVolume) kg")
                    .font(Theme.Font.cardTitle)
                    .foregroundColor(Color.brand.textPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Last")
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(Color.brand.textSecondary)
                Text("\(lastVolume) kg")
                    .font(Theme.Font.cardTitle)
                    .foregroundColor(Color.brand.textPrimary)
            }

            Spacer()
        }
    }
}
