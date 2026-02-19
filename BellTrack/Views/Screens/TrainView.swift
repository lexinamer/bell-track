import SwiftUI

struct TrainView: View {
    @StateObject private var vm = TrainViewModel()
    @State private var selectedBlock: Block?
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var showingNewBlock = false
    @State private var showingLogWorkout = false
    @State private var editingWorkout: Workout?
    @State private var workoutToDelete: Workout?

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            if vm.isLoading {
                VStack {
                    Spacer()
                    ProgressView().padding()
                    Spacer()
                }
                .frame(maxWidth: .infinity)

            } else if vm.activeBlocks.isEmpty && vm.plannedBlocks.isEmpty && vm.pastBlocks.isEmpty {
                EmptyState.noActiveBlock { showingNewBlock = true }

            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // ACTIVE
                        if !vm.activeBlocks.isEmpty {
                            sectionDivider("Active")
                            activeBlocksSection(vm.activeBlocks)
                            Spacer().frame(height: Theme.Space.xl)
                        }

                        // PLANNED
                        if !vm.plannedBlocks.isEmpty {
                            sectionDivider("Up Next")
                            plannedBlocksSection(vm.plannedBlocks)
                            Spacer().frame(height: Theme.Space.xxl)
                        }

                        // COMPLETED
                        if !vm.pastBlocks.isEmpty {
                            sectionDivider("Done")
                            completedBlocksSection(vm.pastBlocks)
                            Spacer().frame(height: Theme.Space.xxl)
                        }
                    }
//                    .padding(.top, Theme.Space.)
                    .padding(.horizontal, Theme.Space.md)
                }
            }
        }
        .navigationTitle("Train")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showingLogWorkout = true } label: {
                        Label("Log Workout", systemImage: "plus")
                    }
                    Button { showingNewBlock = true } label: {
                        Label("Create New Block", systemImage: "square.stack.3d.up")
                    }
                } label: {
                    Image(systemName: "plus").foregroundColor(.white)
                }
            }
        }
        .navigationDestination(item: $selectedBlock) {
            BlockDetailView(block: $0, vm: vm)
        }
        .fullScreenCover(isPresented: $showingLogWorkout) {
            WorkoutFormView(
                workout: nil,
                template: nil,
                onSave: {
                    showingLogWorkout = false
                    Task { await vm.load() }
                },
                onCancel: { showingLogWorkout = false }
            )
        }
        .fullScreenCover(item: $selectedTemplate) { template in
            WorkoutFormView(
                workout: nil,
                template: template,
                onSave: {
                    selectedTemplate = nil
                    Task { await vm.load() }
                },
                onCancel: { selectedTemplate = nil }
            )
        }
        .fullScreenCover(isPresented: $showingNewBlock) {
            BlockFormView(
                vm: vm,
                onSave: { name, start, endDate, pendingTemplates in
                    Task {
                        if let newBlockId = await vm.saveBlock(
                            id: nil,
                            name: name,
                            startDate: start,
                            endDate: endDate,
                            pendingTemplates: pendingTemplates
                        ) {
                            showingNewBlock = false
                            if let block = vm.blocks.first(where: { $0.id == newBlockId }) {
                                selectedBlock = block
                            }
                        }
                    }
                },
                onCancel: { showingNewBlock = false }
            )
        }
        .task { await vm.load() }
    }
    
    // MARK: - Section Divider
    private func sectionDivider(_ title: String) -> some View {
        HStack(spacing: Theme.Space.sm) {
            Rectangle()
                .fill(Color.brand.textSecondary.opacity(0.2))
                .frame(height: 1)
            
            Text(title)
                .font(Theme.Font.cardCaption.weight(.semibold))
                .foregroundColor(Color.brand.textSecondary)
            
            Rectangle()
                .fill(Color.brand.textSecondary.opacity(0.2))
                .frame(height: 1)
        }
        .padding(.vertical, Theme.Space.md)
    }
    
    // MARK: - Block Card
    private func blockCard(
        _ block: Block,
        subtitle: String
    ) -> some View {
        Button {
            selectedBlock = block
        } label: {
            HStack(spacing: 0) {

                Rectangle()
                    .fill(BlockColorPalette.blockPrimary(blockIndex: vm.blockIndex(for: block.id)))
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: Theme.Space.xs) {

                    HStack {
                        Text(block.name)
                            .font(Theme.Font.sectionTitle)
                            .foregroundColor(Color.brand.textPrimary)

                        Spacer()
                    }

                    Text(subtitle)
                        .font(Theme.Font.cardCaption)
                        .foregroundColor(Color.brand.textSecondary)
                }
                .padding(Theme.Space.md)
            }
            .background(Color.brand.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Active Blocks

    private func activeBlocksSection(_ blocks: [Block]) -> some View {
        VStack(spacing: Theme.Space.md) {
            ForEach(blocks.sorted { $0.startDate > $1.startDate }) { block in
                blockCard(
                    block,
                    subtitle: "\(weekProgress(for: block)) • \(workoutCountText(for: block.id))"
                )
            }
        }
    }

    // MARK: - Planned Blocks

    private func plannedBlocksSection(_ blocks: [Block]) -> some View {
        VStack(spacing: Theme.Space.md) {
            ForEach(blocks.sorted { $0.startDate < $1.startDate }) { block in
                blockCard(
                    block,
                    subtitle: dateRangeString(
                        from: block.startDate,
                        to: block.endDate ?? block.startDate
                    )
                )
            }
        }
    }

    // MARK: - Completed Blocks

    private func completedBlocksSection(_ blocks: [Block]) -> some View {
        VStack(spacing: Theme.Space.md) {
            ForEach(blocks.sorted { $0.startDate > $1.startDate }) { block in
                blockCard(
                    block,
                    subtitle: dateRangeString(
                        from: block.startDate,
                        to: block.completedDate ?? block.startDate
                    )
                )
            }
        }
    }

    // MARK: - Helpers

    private func weekProgress(for block: Block) -> String {
        guard let endDate = block.endDate else { return "Ongoing" }
        let cal = Calendar.current
        let total = cal.dateComponents([.weekOfYear], from: block.startDate, to: endDate).weekOfYear ?? 0
        let current = min(cal.dateComponents([.weekOfYear], from: block.startDate, to: Date()).weekOfYear ?? 0, total) + 1
        return "Week \(current) of \(total)"
    }

    private func dateRangeString(from start: Date, to end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    private func workoutCountText(for blockId: String) -> String {
        let count = vm.workouts.filter { $0.blockId == blockId }.count
        return "\(count) workouts"
    }
}
