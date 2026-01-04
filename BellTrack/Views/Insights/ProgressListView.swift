import SwiftUI
import FirebaseAuth
import Foundation

// MARK: - Block insight model

struct BlockInsight: Identifiable {
    let id = UUID()
    let name: String

    let count: Int
    let firstDate: Date
    let lastDate: Date

    let blocks: [WorkoutBlock] // all occurrences of this block
}

// MARK: - Progress View

struct ProgressListView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    @State private var blocks: [WorkoutBlock] = []
    @State private var isLoading = true


    private let firestoreService = FirestoreService()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brand.background.ignoresSafeArea()

                if isLoading {
                    SwiftUI.ProgressView()
                } else if progressItems.isEmpty {
                    VStack(spacing: Spacing.sm) {
                        Text("No progress yet")
                            .font(.system(size: Typography.lg, weight: .semibold))
                            .foregroundColor(Color.brand.textPrimary)

                        Text("Track a block to see your progress over time.")
                            .font(.system(size: Typography.sm))
                            .foregroundColor(Color.brand.textSecondary)
                    }
                } else {
                    List {
                        ForEach(progressItems) { insight in
                            HStack(spacing: 0) {
                                ProgressRow(insight: insight)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.brand.textSecondary)
                            }
                            .padding(.horizontal, Spacing.lg)
                            .contentShape(Rectangle())
                            .background(
                                NavigationLink {
                                    HistoryView(insight: insight)
                                } label: {
                                    EmptyView()
                                }
                                .opacity(0)
                            )
                            // full-width divider, content padded inside
                            .listRowSeparator(.visible)
                            .listRowInsets(.init(
                                top: Spacing.xs,
                                leading: 0,
                                bottom: Spacing.xs,
                                trailing: 0
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
                // Centered title
                ToolbarItem(placement: .principal) {
                    Text("Progress")
                        .font(TextStyles.title)
                        .foregroundColor(Color.brand.textPrimary)
                }
            }
            .task {
                await loadBlocks()
            }
        }
    }

    // MARK: - Derived progress

    private var progressItems: [BlockInsight] {
        // Only tracked blocks
        let tracked = blocks.filter { $0.isTracked }

        // Group by name
        let groups = Dictionary(grouping: tracked) { $0.name }

        return groups.compactMap { name, items in
            // Only show progress for blocks that have been tracked more than once
            guard items.count > 1 else { return nil }

            let sortedByDate = items.sorted { $0.date < $1.date }

            guard let first = sortedByDate.first,
                  let last = sortedByDate.last
            else { return nil }

            return BlockInsight(
                name: name,
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
            print("Error loading blocks for progress: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }

}

// MARK: - Summary row

struct ProgressRow: View {
    let insight: BlockInsight

    // Last block (by date)
    private var lastBlock: WorkoutBlock? {
        insight.blocks.max(by: { $0.date < $1.date })
    }

    private var dateRangeText: String {
        let first = insight.firstDate.formatted(date: .abbreviated, time: .omitted)
        let last = insight.lastDate.formatted(date: .abbreviated, time: .omitted)
        return first == last ? "on \(first)" : "since \(first)"
    }

    // Load text like "16kg"
    private func loadString(for block: WorkoutBlock) -> String? {
        guard let load = block.loadKg else { return nil }

        let base = load.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(load))kg"
            : "\(load)kg"

        return base   // not showing single/double here for now
    }

    // Volume text like "30 reps" or "20 rounds"
    private func volumeString(for block: WorkoutBlock) -> String? {
        guard let value = block.volumeCount else { return nil }

        let v = value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : "\(value)"

        if let kind = block.volumeKind {
            switch kind {
            case .reps:
                return "\(v) reps"
            case .rounds:
                return "\(v) rounds"
            }
        } else {
            return v
        }
    }

    // "Last" line: from the most recent block
    private var lastLine: String {
        guard let block = lastBlock else { return "—" }

        let loadText = loadString(for: block)
        let volumeText = volumeString(for: block)

        switch (loadText, volumeText) {
        case (nil, nil):
            return "—"
        case (let l?, nil):
            return l
        case (nil, let v?):
            return v
        case (let l?, let v?):
            return "\(l) · \(v)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(insight.name)
                .font(TextStyles.bodyStrong)
                .foregroundColor(Color.brand.textPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Last: \(lastLine)")
                    .font(TextStyles.body)
                    .foregroundColor(Color.brand.textSecondary)
            }

            Text("\(insight.count) sessions \(dateRangeText)")
                .font(TextStyles.subtext)
                .foregroundColor(Color.brand.textSecondary)
                .padding(.top, CardStyle.bottomSpacer)
        }
        .padding(.vertical, CardStyle.cardTopBottomPadding)
    }
}
