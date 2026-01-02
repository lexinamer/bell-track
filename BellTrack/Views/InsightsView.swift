import SwiftUI
import FirebaseAuth
import Foundation

struct BlockInsight: Identifiable {
    let id = UUID()
    let name: String
    let trackType: WorkoutBlock.TrackType
    let unit: String?

    let lastValue: Double
    let bestValue: Double
    let count: Int
    let firstDate: Date
    let lastDate: Date

    let blocks: [WorkoutBlock] // all occurrences of this block
}

struct InsightsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss   // ← add this

    @State private var blocks: [WorkoutBlock] = []
    @State private var isLoading = true

    private let firestoreService = FirestoreService()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brand.background.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                } else if insights.isEmpty {
                    VStack(spacing: Spacing.sm) {
                        Text("No insights yet")
                            .font(.system(size: Typography.lg, weight: .semibold))
                            .foregroundColor(Color.brand.textPrimary)

                        Text("Track a block to see your progress over time.")
                            .font(.system(size: Typography.sm))
                            .foregroundColor(Color.brand.textSecondary)
                    }
                } else {
                    List {
                        ForEach(insights) { insight in
                            NavigationLink {
                                HistoryView(insight: insight)
                            } label: {
                                InsightRow(insight: insight)
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.brand.background)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Leading X — same as Add/Edit Workout
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(Color.brand.textPrimary)
                    }
                }

                // Centered title
                ToolbarItem(placement: .principal) {
                    Text("Insights")
                        .font(.system(size: Typography.lg, weight: .semibold))
                        .foregroundColor(Color.brand.textPrimary)
                }
            }
            .task {
                await loadBlocks()
            }
        }
    }

    // MARK: - Derived insights

    private var insights: [BlockInsight] {
        // Only tracked blocks with a metric
        let tracked = blocks.compactMap { block -> WorkoutBlock? in
            guard
                block.isTracked,
                let type = block.trackType,
                type != .none,
                block.trackValue != nil
            else {
                return nil
            }
            return block
        }

        // Group by name ONLY
        let groups = Dictionary(grouping: tracked) { block in
            block.name
        }

        return groups.compactMap { name, items in
            let sortedByDate = items.sorted { $0.date < $1.date }

            guard let first = sortedByDate.first,
                  let last = sortedByDate.last,
                  let type = last.trackType,
                  type != .none
            else { return nil }

            let unit = last.trackUnit
            let values = items.compactMap { $0.trackValue }
            guard let lastValue = last.trackValue else { return nil }

            let bestValue: Double
            switch type {
            case .weight:
                bestValue = values.max() ?? lastValue   // heavier = better
            case .time:
                bestValue = values.min() ?? lastValue   // faster = better
            case .none:
                return nil
            }

            return BlockInsight(
                name: name,
                trackType: type,
                unit: unit,
                lastValue: lastValue,
                bestValue: bestValue,
                count: items.count,
                firstDate: first.date,
                lastDate: last.date,
                blocks: sortedByDate
            )
        }
        .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    // MARK: - Loading

    private func loadBlocks() async {
        guard let userId = authService.user?.uid else {
            await MainActor.run {
                blocks = []
                isLoading = false
            }
            return
        }

        do {
            let fetched = try await firestoreService.fetchBlocks(userId: userId)
            await MainActor.run {
                blocks = fetched
                isLoading = false
            }
        } catch {
            print("Error loading blocks for insights: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Summary row

struct InsightRow: View {
    let insight: BlockInsight

    private var lastFormatted: String {
        format(value: insight.lastValue,
               type: insight.trackType,
               unit: insight.unit)
    }

    private var bestFormatted: String {
        format(value: insight.bestValue,
               type: insight.trackType,
               unit: insight.unit)
    }

    private var dateRangeText: String {
        let first = insight.firstDate.formatted(date: .abbreviated, time: .omitted)
        let last = insight.lastDate.formatted(date: .abbreviated, time: .omitted)

        if first == last {
            return "on \(first)"
        } else {
            return "since \(first)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(insight.name)
                .font(.system(size: Typography.md, weight: .semibold))
                .foregroundColor(Color.brand.textPrimary)

            HStack(spacing: Spacing.sm) {
                Text("Last:")
                    .font(.system(size: Typography.sm, weight: .semibold))
                    .foregroundColor(Color.brand.textSecondary)

                Text(lastFormatted)
                    .font(.system(size: Typography.sm))
                    .foregroundColor(Color.brand.textPrimary)

                Text("·")
                    .foregroundColor(Color.brand.textSecondary)

                Text("Best:")
                    .font(.system(size: Typography.sm, weight: .semibold))
                    .foregroundColor(Color.brand.textSecondary)

                Text(bestFormatted)
                    .font(.system(size: Typography.sm))
                    .foregroundColor(Color.brand.textPrimary)
            }

            Text("\(insight.count) sessions \(dateRangeText)")
                .font(.system(size: Typography.xs))
                .foregroundColor(Color.brand.textSecondary)
        }
        .padding(.vertical, Spacing.sm)
    }

    private func format(value: Double,
                        type: WorkoutBlock.TrackType,
                        unit: String?) -> String {
        switch type {
        case .weight:
            let u = unit ?? "kg"
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
