import SwiftUI

struct InsightsView: View {

    @StateObject private var vm = InsightsViewModel()
    @StateObject private var blocksVM = BlocksViewModel()
    @State private var selectedTemplate: WorkoutTemplate?

    // MARK: - Derived

    private var isEmpty: Bool {
        combinedStats.isEmpty
    }

    private var activeTemplates: [WorkoutTemplate] {
        let activeBlocks = blocksVM.blocks.filter {
            $0.completedDate == nil && $0.startDate <= Date()
        }
        let activeBlockIds = activeBlocks.map { $0.id }
        return blocksVM.templates
            .filter { activeBlockIds.contains($0.blockId) }
            .sorted { $0.name < $1.name }
    }

    // MARK: - View

    var body: some View {

        ZStack {

            Color.brand.background
                .ignoresSafeArea()

            if vm.isLoading {

                ProgressView()

            } else if isEmpty {

                emptyState

            } else {

                ScrollView {

                    VStack(
                        alignment: .leading,
                        spacing: Theme.Space.xl
                    ) {

                        filterSection

                        muscleLoadSection
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(activeTemplates) { template in
                        Button {
                            selectedTemplate = template
                        } label: {
                            Text(template.name)
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await vm.load()
            await blocksVM.load()
        }

        // MARK: - New Workout Sheet (from template)

        .fullScreenCover(item: $selectedTemplate) { template in
            WorkoutFormView(
                workout: nil,
                template: template,
                onSave: {
                    selectedTemplate = nil
                    Task { await vm.load() }
                },
                onCancel: {
                    selectedTemplate = nil
                }
            )
        }

    }

    // MARK: - Empty State

    private var emptyState: some View {

        VStack(spacing: Theme.Space.lg) {

            Spacer()

            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 44))
                .foregroundColor(Color.brand.textSecondary)

            Text("No insights yet")
                .font(Theme.Font.emptyStateTitle)
                .foregroundColor(Color.brand.textPrimary)

            Text("Log workouts to see muscle load and training balance.")
                .font(Theme.Font.emptyStateDescription)
                .foregroundColor(Color.brand.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Space.xl)

            Spacer()
        }
    }

    // MARK: - Filter Section

    private var filterSection: some View {

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
    }

    // MARK: - Muscle Load Section

    private var muscleLoadSection: some View {

        VStack(alignment: .leading, spacing: Theme.Space.md) {

            HStack {

                Text("Muscle Load")
                    .font(Theme.Font.sectionTitle)
                    .foregroundColor(Color.brand.textPrimary)

                Spacer()

                HStack(spacing: Theme.Space.md) {

                    Label {
                        Text("Primary")
                            .font(Theme.Font.cardCaption)
                            .foregroundColor(Color.brand.textSecondary)
                    } icon: {
                        Circle()
                            .fill(Color.brand.primary)
                            .frame(width: 8, height: 8)
                    }

                    Label {
                        Text("Secondary")
                            .font(Theme.Font.cardCaption)
                            .foregroundColor(Color.brand.textSecondary)
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

    // MARK: - Combined Stats

    private var combinedStats: [CombinedMuscleStat] {

        let primary = vm.primaryStats
        let secondary = vm.secondaryStats

        let muscles = Set(primary.map(\.muscle))
            .union(secondary.map(\.muscle))

        let raw = muscles.map {
            muscle -> (MuscleGroup, Double, Double, Double) in

            let p = primary.first(where: { $0.muscle == muscle })?.percent ?? 0
            let s = secondary.first(where: { $0.muscle == muscle })?.percent ?? 0

            let primaryValue = p * 0.7
            let secondaryValue = s * 0.3
            let total = primaryValue + secondaryValue

            return (muscle, total, primaryValue, secondaryValue)
        }
        .filter { $0.1 > 0 }

        let maxTotal = raw.map(\.1).max() ?? 0
        guard maxTotal > 0 else { return [] }

        let barScale = 0.75 / maxTotal

        return raw
            .map {
                CombinedMuscleStat(
                    muscle: $0.0,
                    displayPercent: $0.1,
                    primaryBarWidth: $0.2 * barScale,
                    secondaryBarWidth: $0.3 * barScale
                )
            }
            .sorted { $0.displayPercent > $1.displayPercent }
    }

    // MARK: - Muscle Row

    private func muscleRow(stat: CombinedMuscleStat) -> some View {

        VStack(alignment: .leading, spacing: Theme.Space.xs) {

            HStack {

                Text(stat.muscle.displayName)
                    .font(Theme.Font.cardTitle)
                    .foregroundColor(Color.brand.textPrimary)

                Spacer()

                Text("\(Int(round(stat.displayPercent * 100)))%")
                    .font(Theme.Font.cardSecondary)
                    .foregroundColor(Color.brand.textSecondary)
            }

            GeometryReader { geo in

                ZStack(alignment: .leading) {

                    Capsule()
                        .fill(Color.brand.surface)

                    HStack(spacing: 0) {

                        Rectangle()
                            .fill(Color.brand.primary)
                            .frame(width: geo.size.width * stat.primaryBarWidth)

                        Rectangle()
                            .fill(Color.brand.primary.opacity(0.55))
                            .frame(width: geo.size.width * stat.secondaryBarWidth)
                    }
                }
                .frame(height: 8)
                .clipShape(Capsule())
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

        Button(action: action) {

            Text(title)
                .font(Theme.Font.cardSecondary)
                .padding(.horizontal, Theme.Space.md)
                .padding(.vertical, Theme.Space.xs)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(
                            isSelected
                            ? Color.brand.primary.opacity(0.15)
                            : Color.clear
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .stroke(
                            isSelected
                            ? Color.clear
                            : Color.brand.border
                        )
                )
                .foregroundColor(
                    isSelected
                    ? Color.brand.primary
                    : Color.brand.textPrimary
                )
        }
    }
}

// MARK: - Combined Model

struct CombinedMuscleStat: Identifiable {

    let id = UUID()
    let muscle: MuscleGroup
    let displayPercent: Double
    let primaryBarWidth: Double
    let secondaryBarWidth: Double
}
