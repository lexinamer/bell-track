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
                            .font(.system(size: Typography.sm, weight: .semibold))
                            .foregroundColor(Color.brand.textPrimary)

                        Spacer()

                        if let value = block.trackValue,
                           value == bestValue {
                            Text("Best")
                                .font(.system(size: Typography.xs, weight: .semibold))
                                .padding(.horizontal, Spacing.xs)
                                .padding(.vertical, 2)
                                .background(Color.brand.primary.opacity(0.1))
                                .foregroundColor(Color.brand.primary)
                                .cornerRadius(CornerRadius.sm)
                        }
                    }

                    if let value = block.trackValue {
                        Text(format(value: value))
                            .font(.system(size: Typography.sm))
                            .foregroundColor(Color.brand.textPrimary)
                    }

                    let trimmedDetails = block.details.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedDetails.isEmpty {
                        Text(trimmedDetails)
                            .font(.system(size: Typography.sm))
                            .foregroundColor(Color.brand.textSecondary)
                    }
                }
                .padding(.vertical, Spacing.sm)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.brand.background)
        .navigationTitle(insight.name)
        .navigationBarTitleDisplayMode(.inline)
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

        case .none:
            return "-"
        }
    }
}
