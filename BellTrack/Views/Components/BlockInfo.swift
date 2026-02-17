import SwiftUI

struct BlockInfo: View {
    let block: Block
    let balanceFocusLabel: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text("\(weekProgressText) • \(dateRangeText)")
                    .font(Theme.Font.cardSecondary)
                    .foregroundColor(Color.brand.textSecondary)

                Text(balanceFocusLabel)
                    .font(Theme.Font.cardSecondary)
                    .foregroundColor(Color.brand.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var dateRangeText: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"

        if let endDate = block.endDate {
            let end = dateFormatter.string(from: endDate)
            return "Ends \(end)"
        } else {
            let start = dateFormatter.string(from: block.startDate)
            return "Started \(start)"
        }
    }

    private var weekProgressText: String {
        guard let endDate = block.endDate else { return "Ongoing" }

        let calendar = Calendar.current
        let totalWeeks = calendar.dateComponents([.weekOfYear], from: block.startDate, to: endDate).weekOfYear ?? 0
        let currentWeek = min(
            calendar.dateComponents([.weekOfYear], from: block.startDate, to: Date()).weekOfYear ?? 0,
            totalWeeks
        ) + 1

        guard totalWeeks > 0 else { return "Ongoing" }

        return "Week \(currentWeek) of \(totalWeeks + 1)"
    }
}
