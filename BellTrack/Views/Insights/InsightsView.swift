import SwiftUI
import FirebaseAuth
import Foundation

// MARK: - Insight model

struct BlockInsight: Identifiable {
    let id = UUID()
    let name: String

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
                            HStack(spacing: 0) {
                                InsightRow(insight: insight)
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
                ToolbarItem(placement: .principal) {
                    Text("Insights")
                        .font(TextStyles.title)
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
        // Only tracked blocks
        let tracked = blocks.filter { $0.isTracked }

        // Group by name
        let groups = Dictionary(grouping: tracked) { $0.name }

        return groups.compactMap { name, items in
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

    // "Best" line: max load and max volume across history
    private var bestLine: String {
        // Best load (max kg)
        let bestLoad = insight.blocks
            .compactMap { $0.loadKg }
            .max()

        let loadText: String? = {
            guard let bestLoad else { return nil }
            let base = bestLoad.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(bestLoad))kg"
                : "\(bestLoad)kg"
            return base
        }()

        // Best volume (max volumeCount) and its kind
        let bestVolumeBlock = insight.blocks
            .filter { $0.volumeCount != nil }
            .max(by: { ($0.volumeCount ?? 0) < ($1.volumeCount ?? 0) })

        let volumeText: String? = {
            guard let block = bestVolumeBlock else { return nil }
            return volumeString(for: block)
        }()

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

                Text("Best: \(bestLine)")
                    .font(TextStyles.body)
                    .foregroundColor(Color.brand.textSecondary)
            }

            Text("\(insight.count) sessions \(dateRangeText)")
                .font(TextStyles.subtext)
                .foregroundColor(Color.brand.secondary)
                .padding(.top, CardStyle.bottomSpacer)
        }
        .padding(.vertical, CardStyle.cardTopBottomPadding)
    }
}
