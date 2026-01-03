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

// MARK: - Insights View
struct InsightsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    @State private var blocks: [WorkoutBlock] = []
    @State private var isLoading = true

    // rename state
    @State private var renameTarget: BlockInsight?
    @State private var newName: String = ""
    @State private var isRenaming = false

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
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    renameTarget = insight
                                    newName = insight.name
                                    isRenaming = true
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(Color.brand.primary)
                            }
                            // full-width dividers, white cards
                            .listRowSeparator(.visible)
                            .listRowInsets(.init(
                                top: 0,
                                leading: 0,
                                bottom: 0,
                                trailing: WorkoutListStyle.cardHorizontalPadding
                            ))
                            .listRowBackground(Color.brand.surface)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
        // Rename alert
        .alert("Rename Movement", isPresented: $isRenaming) {
            TextField("New name", text: $newName)

            Button("Save") {
                guard let target = renameTarget else { return }
                let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, trimmed != target.name else { return }

                Task {
                    await renameMovement(from: target.name, to: trimmed)
                }
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will rename this movement everywhere in your history.")
        }
    }

    // MARK: - Derived insights

    private var insights: [BlockInsight] {
        // Only tracked blocks with a metric
        let tracked = blocks.compactMap { block -> WorkoutBlock? in
            guard
                block.isTracked,
                let _ = block.trackType,
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
                  let type = last.trackType
            else { return nil }

            let unit = last.trackUnit
            let values = items.compactMap { $0.trackValue }
            guard let lastValue = last.trackValue else { return nil }

            let bestValue: Double
            switch type {
            case .weight, .reps, .time:
                // Higher = better (heavier, more reps, or longer)
                bestValue = values.max() ?? lastValue
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

    // MARK: - Rename

    private func renameMovement(from oldName: String, to newName: String) async {
        guard let userId = authService.user?.uid else { return }

        do {
            let fetched = try await firestoreService.fetchBlocks(userId: userId)

            let matching = fetched.filter { $0.name == oldName }

            for var block in matching {
                block.name = newName
                try await firestoreService.saveBlock(block)
            }

            await loadBlocks()   // refresh insights
        } catch {
            print("Rename failed:", error)
        }
    }
}

// MARK: - Summary row

struct InsightRow: View {
    let insight: BlockInsight

    // MARK: - Computed display strings

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
        let last  = insight.lastDate.formatted(date: .abbreviated, time: .omitted)

        return first == last ? "on \(first)" : "since \(first)"
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(insight.name)
                .font(TextStyles.bodyStrong)
                .foregroundColor(Color.brand.textPrimary)

            HStack(spacing: Spacing.sm) {
                Text("Last:")
                    .font(TextStyles.body)
                Text(lastFormatted)
                    .font(TextStyles.body)

                Text("·")

                Text("Best:")
                    .font(TextStyles.body)
                Text(bestFormatted)
                    .font(TextStyles.body)
            }
            .foregroundColor(Color.brand.textPrimary)

            Text("\(insight.count) sessions \(dateRangeText)")
                .font(TextStyles.subtext)
                .foregroundColor(Color.brand.textSecondary)
        }
        .padding(.vertical, WorkoutListStyle.cardTopBottomPadding)
        .padding(.horizontal, WorkoutListStyle.cardHorizontalPadding)
    }

    // MARK: - Formatting helper

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

        case .reps:
            let v = value.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(value))"
                : "\(value)"
            return "\(v) reps"
        }
    }
}
