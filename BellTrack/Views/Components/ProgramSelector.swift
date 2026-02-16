import SwiftUI

struct ProgramSelector: View {

    let block: Block
    let onTap: () -> Void

    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"

        if let endDate = block.endDate {
            let start = formatter.string(from: block.startDate)
            let end = formatter.string(from: endDate)
            return "\(start) – \(end)"
        } else {
            let start = formatter.string(from: block.startDate)
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

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: Theme.Space.md) {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    HStack(spacing: Theme.Space.sm) {
                        Text(block.name)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(Color.brand.textPrimary)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.brand.textSecondary)
                    }

                    HStack(spacing: Theme.Space.smp) {
                        Text(dateRangeText)
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(Color.brand.textSecondary)

                        Text("•")
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(Color.brand.textSecondary)

                        Text(weekProgressText)
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(Color.brand.textSecondary)
                    }
                }

                Spacer()
            }
            .padding(Theme.Space.md)
            .background(Color.brand.surface)
            .cornerRadius(Theme.Radius.md)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
