import SwiftUI

struct InsightsView: View {

    @StateObject private var vm = InsightsViewModel()

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            // Content
            if vm.isLoading {
                ProgressView()
            } else if vm.muscleStats.isEmpty {
                emptyState
            } else {
                let maxSets = vm.muscleStats.first?.totalSets ?? 1

                List {
                    // Block picker
                    if !vm.blocks.isEmpty {
                        Picker("Filter", selection: Binding(
                            get: { vm.selectedBlockId ?? "__all__" },
                            set: { vm.selectBlock($0 == "__all__" ? nil : $0) }
                        )) {
                            Text("All Time").tag("__all__")
                            ForEach(vm.blocks) { block in
                                Text(block.name).tag(block.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.horizontal)
                    }

                    ForEach(vm.muscleStats) { stat in
                        muscleRow(stat: stat, maxSets: maxSets)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await vm.load()
        }
    }

    // MARK: - Muscle Row

    private func muscleRow(stat: MuscleStat, maxSets: Int) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack {
                Text(stat.muscle.displayName)
                    .font(Theme.Font.cardTitle)
                    .foregroundColor(.primary)

                Spacer()

                Text("\(stat.totalSets) sets")
                    .font(Theme.Font.cardSecondary)
                    .foregroundColor(.secondary)

                Text("\(stat.exerciseCount) exercises")
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(.secondary)
            }

            // Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    HStack(spacing: 0) {
                        // Primary portion
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.brand.primary)
                            .frame(
                                width: max(0, geo.size.width * barFraction(stat.primarySets, max: maxSets)),
                                height: 8
                            )

                        // Secondary portion
                        if stat.secondarySets > 0 {
                            RoundedRectangle(cornerRadius: 0)
                                .fill(Color.brand.primary.opacity(0.4))
                                .frame(
                                    width: max(0, geo.size.width * barFraction(stat.secondarySets, max: maxSets)),
                                    height: 8
                                )
                                .clipShape(
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: 0,
                                        bottomLeadingRadius: 0,
                                        bottomTrailingRadius: 4,
                                        topTrailingRadius: 4
                                    )
                                )
                        }
                    }
                }
            }
            .frame(height: 8)

            // Legend
            HStack(spacing: Theme.Space.md) {
                HStack(spacing: Theme.Space.xs) {
                    Circle()
                        .fill(Color.brand.primary)
                        .frame(width: 6, height: 6)
                    Text("Primary \(stat.primarySets)")
                        .font(Theme.Font.cardCaption)
                        .foregroundColor(.secondary)
                }

                if stat.secondarySets > 0 {
                    HStack(spacing: Theme.Space.xs) {
                        Circle()
                            .fill(Color.brand.primary.opacity(0.4))
                            .frame(width: 6, height: 6)
                        Text("Secondary \(stat.secondarySets)")
                            .font(Theme.Font.cardCaption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Helpers

    private func barFraction(_ value: Int, max: Int) -> CGFloat {
        guard max > 0 else { return 0 }
        return CGFloat(value) / CGFloat(max)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Space.mdp) {
            Image(systemName: "chart.bar")
                .font(.system(size: Theme.IconSize.xl))
                .foregroundColor(.secondary)

            Text("No muscle data yet")
                .font(Theme.Font.cardTitle)

            Text("Add muscle groups to your exercises to see insights.")
                .font(Theme.Font.cardSecondary)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }
}
