import SwiftUI

struct InsightsView: View {

    @StateObject private var vm = InsightsViewModel()

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            if vm.isLoading {
                ProgressView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.lg) {

                        // Block filter chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Space.sm) {
                                filterChip(
                                    title: "All",
                                    isSelected: vm.selectedBlockId == nil
                                ) {
                                    vm.selectBlock(nil)
                                }

                                ForEach(vm.blocks) { block in
                                    filterChip(
                                        title: block.name,
                                        isSelected: vm.selectedBlockId == block.id
                                    ) {
                                        vm.selectBlock(block.id)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Combined muscle load
                        VStack(alignment: .leading, spacing: Theme.Space.md) {
                            HStack {
                                Text("Muscle Load")
                                    .font(Theme.Font.sectionTitle)

                                Spacer()

                                HStack(spacing: Theme.Space.md) {
                                    Label {
                                        Text("Primary")
                                            .font(Theme.Font.cardCaption)
                                            .foregroundColor(.secondary)
                                    } icon: {
                                        Circle()
                                            .fill(Color.brand.primary)
                                            .frame(width: 8, height: 8)
                                    }

                                    Label {
                                        Text("Secondary")
                                            .font(Theme.Font.cardCaption)
                                            .foregroundColor(.secondary)
                                    } icon: {
                                        Circle()
                                            .fill(Color.brand.primary.opacity(0.55))
                                            .frame(width: 8, height: 8)
                                    }
                                }
                            }
                            .padding(.horizontal)

                            ForEach(combinedStats) { stat in
                                muscleRow(stat: stat)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await vm.load()
        }
        .onAppear {
            Task { await vm.load() }
        }
    }

    // MARK: - Combined Stats (Primary + Secondary)

    private var combinedStats: [CombinedMuscleStat] {
        let primary = vm.primaryStats
        let secondary = vm.secondaryStats

        let muscles = Set(primary.map(\.muscle))
            .union(secondary.map(\.muscle))

        let combined = muscles.map { muscle -> CombinedMuscleStat in
            let p = primary.first(where: { $0.muscle == muscle })?.percent ?? 0
            let s = secondary.first(where: { $0.muscle == muscle })?.percent ?? 0

            let primaryValue = p * 0.7
            let secondaryValue = s * 0.3
            let total = primaryValue + secondaryValue

            return CombinedMuscleStat(
                muscle: muscle,
                percent: total,
                primaryPercent: primaryValue,
                secondaryPercent: secondaryValue
            )
        }

        let maxValue = combined.map(\.percent).max() ?? 0
        guard maxValue > 0 else { return [] }

        return combined
            .map {
                CombinedMuscleStat(
                    muscle: $0.muscle,
                    percent: $0.percent / maxValue,
                    primaryPercent: $0.primaryPercent / maxValue,
                    secondaryPercent: $0.secondaryPercent / maxValue
                )
            }
            .sorted { $0.percent > $1.percent }
    }

    // MARK: - Muscle Row

    private func muscleRow(stat: CombinedMuscleStat) -> some View {
        let safePercent = stat.percent.isFinite ? stat.percent : 0
        let safePrimary = stat.primaryPercent.isFinite ? stat.primaryPercent : 0
        let safeSecondary = stat.secondaryPercent.isFinite ? stat.secondaryPercent : 0

        return VStack(alignment: .leading, spacing: Theme.Space.xs) {
            HStack {
                Text(stat.muscle.displayName)
                    .font(Theme.Font.cardTitle)

                Spacer()

                Text("\(Int(safePercent * 100))%")
                    .font(Theme.Font.cardSecondary)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.brand.primary)
                            .frame(width: geo.size.width * safePrimary)

                        Rectangle()
                            .fill(Color.brand.primary.opacity(0.55))
                            .frame(width: geo.size.width * safeSecondary)
                    }
                    .frame(height: 8)
                    .clipShape(Capsule())
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, Theme.Space.xs)
    }

    // MARK: - Filter Chip

    private func filterChip(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        return Button(action: action) {
            Text(title)
                .font(Theme.Font.cardSecondary)
                .padding(.horizontal, Theme.Space.md)
                .padding(.vertical, Theme.Space.xs)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            isSelected
                                ? Color.brand.primary.opacity(0.15)
                                : Color.clear
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ? Color.clear : Color(.systemGray4),
                            lineWidth: 1
                        )
                )
                .foregroundColor(
                    isSelected ? Color.brand.primary : .primary
                )
        }
    }
}

// MARK: - Combined Model

struct CombinedMuscleStat: Identifiable {
    let id = UUID()
    let muscle: MuscleGroup
    let percent: Double
    let primaryPercent: Double
    let secondaryPercent: Double
}
