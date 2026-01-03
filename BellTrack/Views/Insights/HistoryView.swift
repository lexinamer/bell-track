import SwiftUI
import Foundation

struct HistoryView: View {
    let insight: BlockInsight

    // newest first
    private var sortedBlocks: [WorkoutBlock] {
        insight.blocks.sorted { $0.date > $1.date }
    }

    private var bestValue: Double {
        insight.bestValue
    }

    var body: some View {
        List {
            ForEach(sortedBlocks, id: \.id) { block in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text(block.date.formatted(date: .abbreviated, time: .omitted))
                            .font(TextStyles.bodyStrong)
                            .foregroundColor(Color.brand.textPrimary)

                        Spacer()

                        if let value = block.trackValue,
                           isBest(value: value) {
                            Text("Best")
                                .font(TextStyles.subtextStrong)
                                .padding(.horizontal, Spacing.xs)
                                .padding(.vertical, 2)
                                .background(Color.brand.primary.opacity(0.08))
                                .foregroundColor(Color.brand.primary)
                                .cornerRadius(CornerRadius.sm)
                        }
                    }

                    if let value = block.trackValue {
                        Text(format(value: value))
                            .font(TextStyles.body)
                            .foregroundColor(Color.brand.textPrimary)
                    }

                    let trimmedDetails = block.details
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if !trimmedDetails.isEmpty {
                        Text(trimmedDetails)
                            .font(TextStyles.body)
                            .foregroundColor(Color.brand.textSecondary)
                    }
                }
                .padding(.vertical, Spacing.sm)
                // match Insights / Workouts row chrome
                .listRowSeparator(.visible)
                .listRowInsets(.init(
                    top: Spacing.xs,
                    leading: Spacing.lg,
                    bottom: Spacing.xs,
                    trailing: Spacing.lg
                ))
                .listRowBackground(Color.brand.surface)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.brand.background)
        .navigationTitle(insight.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func isBest(value: Double) -> Bool {
        abs(value - bestValue) < 0.0001
    }

    private func format(value: Double) -> String {
        switch insight.trackType {
        case .weight:
            let u = insight.unit ?? "kg"
            let v = value.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(value))"
                : "\(value)"
            return "\(v)\(u)"

        case .time:
            let minutes = Int(value) / 60
            let seconds = Int(value) % 60
            if seconds == 0 {
                return "\(minutes) mins"
            } else {
                return String(format: "%d:%02d mins", minutes, seconds)
            }

        case .reps:
            let reps = value.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(value))"
                : "\(value)"
            return "\(reps) reps"
        }
    }
}
