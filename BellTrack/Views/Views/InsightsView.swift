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
                    VStack(alignment: .leading, spacing: Theme.Space.xl) {

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

        // Build absolute weighted percentages
        let raw = muscles.map { muscle -> (muscle: MuscleGroup, total: Double, primary: Double, secondary: Double) in
            let p = primary.first(where: { $0.muscle == muscle })?.percent ?? 0
            let s = secondary.first(where: { $0.muscle == muscle })?.percent ?? 0

            let primaryValue = p * 0.7
            let secondaryValue = s * 0.3
            let total = primaryValue + secondaryValue

            return (muscle, total, primaryValue, secondaryValue)
        }
        .filter { $0.total > 0 }

        // Scale bars so the top muscle fills ~75% width (visual impact)
        // but labels stay as true absolute percentages
        let maxTotal = raw.map(\.total).max() ?? 0
        guard maxTotal > 0 else { return [] }
        let barScale = 0.75 / maxTotal

        return raw
            .map {
                CombinedMuscleStat(
                    muscle: $0.muscle,
                    displayPercent: $0.total,
                    primaryBarWidth: $0.primary * barScale,
                    secondaryBarWidth: $0.secondary * barScale
                )
            }
            .sorted { $0.displayPercent > $1.displayPercent }
    }

    // MARK: - Muscle Row

    private func muscleRow(stat: CombinedMuscleStat) -> some View {
        let primaryBar = stat.primaryBarWidth.isFinite ? stat.primaryBarWidth : 0
        let secondaryBar = stat.secondaryBarWidth.isFinite ? stat.secondaryBarWidth : 0

        return VStack(alignment: .leading, spacing: Theme.Space.xs) {
            HStack {
                Text(stat.muscle.displayName)
                    .font(Theme.Font.cardTitle)

                Spacer()

                Text("\(Int(round(stat.displayPercent * 100)))%")
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
                            .frame(width: geo.size.width * primaryBar)

                        Rectangle()
                            .fill(Color.brand.primary.opacity(0.55))
                            .frame(width: geo.size.width * secondaryBar)
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
    let displayPercent: Double      // absolute weighted percentage (0–1) for the label
    let primaryBarWidth: Double     // scaled primary portion of bar (for visual fill)
    let secondaryBarWidth: Double   // scaled secondary portion of bar (for visual fill)
}
