import SwiftUI

struct LargeTitleHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(Color.brand.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color.brand.background)
    }
}
