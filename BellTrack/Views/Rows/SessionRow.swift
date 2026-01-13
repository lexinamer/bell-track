import SwiftUI

struct SessionRow: View {

    let session: Session
    let onTap: () -> Void

    private var detailsText: String {
        let trimmed = (session.details ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "No details" : trimmed
    }

    private var dateLine: String {
        session.date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(detailsText)
                .font(Theme.Font.body)
                .foregroundColor(detailsText == "No details" ? Color.brand.textSecondary : Color.brand.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(dateLine)
                .font(Theme.Font.meta)
                .foregroundColor(Color.brand.textSecondary)
                .monospacedDigit()
        }
        .padding(.vertical, Theme.Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}
