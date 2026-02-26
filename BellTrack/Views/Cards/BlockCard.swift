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
    let lastWorkoutDate: Date?
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onComplete: (() -> Void)?

    private var isCompleted: Bool {
        if case .completed = state { return true }
        return false
    }

    private var subtitle: String {
        switch state {
        case .active(let weekProgress, let endDate):
            return endDate.isEmpty
            ? "\(weekProgress) · Ongoing"
            : "\(weekProgress) · Ends \(endDate)"
        case .upcoming(let startDate):
            return "Starts \(startDate)"
        case .completed(let dateRange):
            return dateRange
        }
    }

    private var accentColor: Color {
        BlockColorPalette.blockPrimary(blockIndex: blockIndex)
    }

    private var lastWorkoutText: String? {
        guard let date = lastWorkoutDate else { return nil }
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())).day ?? 2
        return "\(days)d ago"
    }

    // Right-side badge: nothing for completed, "No workouts" if never logged, otherwise "Last: X"
    private var trailingText: String? {
        if isCompleted { return nil }
        guard let text = lastWorkoutText else { return "No workouts" }
        return "Last: \(text)"
    }

    var body: some View {
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

            if let trailingText {
                Text(trailingText)
                    .font(Theme.Font.cardBadge)
                    .foregroundColor(Color.brand.textSecondary)
                    .padding(.trailing, Theme.Space.md)
            }
        }
        .background(Color.brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .contextMenu {
            Button { onEdit() } label: {
                Label("Edit", systemImage: "square.and.pencil")
            }

            if let onComplete {
                Button { onComplete() } label: {
                    Label("Mark as Complete", systemImage: "checkmark.circle")
                }
            }

            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
