import SwiftUI

struct TemplateCard: View {

    let template: WorkoutTemplate
    let completionCount: Int
    let volumeDelta: Int?
    let repsDelta: Int?
    let accentColor: Color
    let onLog: (() -> Void)?
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    private var completionText: String {
        completionCount == 1 ? "1 workout" : "\(completionCount) workouts"
    }

    private var deltaText: String? {
        guard completionCount >= 2 else { return nil }
        if let delta = volumeDelta {
            let abs = Swift.abs(delta)
            if delta > 0 { return "↑ \(abs) kg" }
            if delta < 0 { return "↓ \(abs) kg" }
            return "= same as last"
        }
        if let delta = repsDelta {
            let abs = Swift.abs(delta)
            if delta > 0 { return "↑ \(abs) reps" }
            if delta < 0 { return "↓ \(abs) reps" }
            return "= same as last"
        }
        return nil
    }

    private var deltaColor: Color {
        let delta = volumeDelta ?? repsDelta
        guard let delta else { return Color.brand.textSecondary }
        if delta > 0 { return Color.brand.success }
        if delta < 0 { return Color.brand.destructive }
        return Color.brand.textSecondary
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 4)

            HStack(alignment: .center, spacing: Theme.Space.md) {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text(template.name)
                        .font(Theme.Font.sectionTitle)
                        .foregroundColor(Color.brand.textPrimary)

                    HStack(spacing: Theme.Space.xs) {
                        Text(completionText)
                            .font(Theme.Font.cardCaption)
                            .foregroundColor(Color.brand.textSecondary)

                        if let delta = deltaText {
                            Text("·")
                                .font(Theme.Font.cardCaption)
                                .foregroundColor(Color.brand.textSecondary)
                            Text(delta)
                                .font(Theme.Font.cardCaption)
                                .foregroundColor(deltaColor)
                        }
                    }
                }

                Spacer()

                if onLog != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Log")
                    }
                    .font(Theme.Font.cardCaption.weight(.medium))
                    .foregroundColor(Color.brand.textSecondary)
                    .fixedSize()
                }
            }
            .padding(Theme.Space.md)
        }
        .background(Color.brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .contentShape(Rectangle())
        .onTapGesture { onLog?() }
        .contextMenu {
            if let onEdit {
                Button { onEdit() } label: {
                    Label("Edit", systemImage: "square.and.pencil")
                }
            }
            if let onDelete {
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}
