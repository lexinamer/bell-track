import SwiftUI

struct BlockRow: View {

    let block: Block
    let onEdit: () -> Void
    let onComplete: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            Color.brand.surface

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(block.name)
                        .font(Theme.Font.title)
                        .foregroundColor(Color.brand.textPrimary)

                    Spacer()

                    Menu {
                        Button("Edit block") { onEdit() }

                        if !block.isCompleted {
                            Button("Mark complete") { onComplete() }
                        }

                        Button(role: .destructive) { onDelete() } label: {
                            Text("Delete block")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .rotationEffect(.degrees(90))
                            .foregroundColor(Color.brand.textSecondary)
                            .frame(width: 32, height: 32)
                    }
                }

                Text(block.fullDateRangeText)
                    .font(Theme.Font.body)
                    .foregroundColor(Color.brand.textSecondary)

                Rectangle()
                    .fill(Color.brand.border)
                    .frame(height: 1)
                    .padding(.top, Theme.Space.sm)
            }
            .padding(.horizontal, Theme.Space.lg)
            .padding(.vertical, Theme.Space.lg)
        }
        .frame(maxWidth: .infinity)
    }
}
