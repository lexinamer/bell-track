import SwiftUI

struct BlockCard: View {

    let block: Block
    let workoutCount: Int
    let isExpanded: Bool
    let backgroundColor: Color

    let onToggle: () -> Void
    let onEdit: () -> Void
    let onComplete: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            // Name
            Text(block.name)
                .font(Theme.Font.cardTitle)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)

            // Progress text
            Text(progressText)
                .font(Theme.Font.cardCaption)
                .foregroundColor(.white)

            // Workout count
            Text("\(workoutCount) workouts")
                .font(Theme.Font.cardCaption)
                .foregroundColor(.white)

            // Expanded notes
            if isExpanded, let notes = block.notes, !notes.isEmpty {
                Text("Goal: \(notes)")
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(.white)
                    .padding(.top, Theme.Space.xs)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            ZStack {
                backgroundColor
                if isExpanded {
                    Color.black.opacity(0.15)
                }
            }
        )
        .cornerRadius(12)
        .shadow(
            color: isExpanded
                ? backgroundColor.opacity(0.6)
                : Color.black.opacity(0.1),
            radius: isExpanded ? 10 : 2,
            x: 0,
            y: isExpanded ? 5 : 1
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation { onToggle() }
        }
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }

            if block.completedDate == nil {
                Button(action: onComplete) {
                    Label("Complete", systemImage: "checkmark")
                }
            }

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Progress Text (now belongs here)

    private var progressText: String {
        switch block.type {
        case .ongoing:
            let weeksSinceStart =
                Calendar.current.dateComponents(
                    [.weekOfYear],
                    from: block.startDate,
                    to: Date()
                ).weekOfYear ?? 0

            return "Week \(max(1, weeksSinceStart + 1)) (ongoing)"

        case .duration:
            if let weeks = block.durationWeeks {
                let weeksSinceStart =
                    Calendar.current.dateComponents(
                        [.weekOfYear],
                        from: block.startDate,
                        to: Date()
                    ).weekOfYear ?? 0

                let currentWeek = min(max(1, weeksSinceStart + 1), weeks)
                return "Week \(currentWeek) of \(weeks)"
            } else {
                return ""
            }
        }
    }
}
