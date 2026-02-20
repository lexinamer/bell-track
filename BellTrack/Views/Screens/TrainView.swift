import SwiftUI

struct TrainView: View {
    @StateObject private var vm = TrainViewModel()
    @State private var selectedBlock: Block?
    @State private var showingNewBlock = false
    @State private var showingLogWorkout = false
    @State private var selectedTemplate: WorkoutTemplate?

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
                    .offset(y: -60)

            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        if !vm.activeBlocks.isEmpty {
                            SectionDivider(title: "Active")
                            activeBlocksSection(vm.activeBlocks)
                            Spacer().frame(height: Theme.Space.xl)
                        }

                        if !vm.plannedBlocks.isEmpty {
                            SectionDivider(title: "Up Next")
                            plannedBlocksSection(vm.plannedBlocks)
                            Spacer().frame(height: Theme.Space.xxl)
                        }

                        if !vm.pastBlocks.isEmpty {
                            SectionDivider(title: "Done")
                            completedBlocksSection(vm.pastBlocks)
                            Spacer().frame(height: Theme.Space.xxl)
                        }
                    }
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
                onSave: { name, goal, start, endDate in
                    Task {
                        if let newBlockId = await vm.saveBlock(
                            id: nil,
                            name: name,
                            goal: goal,
                            startDate: start,
                            endDate: endDate
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

    // MARK: - Block Sections

    private func activeBlocksSection(_ blocks: [Block]) -> some View {
        VStack(spacing: Theme.Space.md) {
            ForEach(blocks) { block in
                BlockCard(
                    block: block,
                    state: .active(
                        weekProgress: vm.weekProgress(for: block),
                        endDate: vm.formattedEndDate(for: block)
                    ),
                    blockIndex: vm.blockIndex(for: block.id),
                    onTap: { selectedBlock = block }
                )
            }
        }
    }

    private func plannedBlocksSection(_ blocks: [Block]) -> some View {
        VStack(spacing: Theme.Space.md) {
            ForEach(blocks) { block in
                BlockCard(
                    block: block,
                    state: .upcoming(startDate: vm.formattedStartDate(for: block)),
                    blockIndex: vm.blockIndex(for: block.id),
                    onTap: { selectedBlock = block }
                )
            }
        }
    }

    private func completedBlocksSection(_ blocks: [Block]) -> some View {
        VStack(spacing: Theme.Space.md) {
            ForEach(blocks) { block in
                BlockCard(
                    block: block,
                    state: .completed(dateRange: vm.dateRange(for: block)),
                    blockIndex: vm.blockIndex(for: block.id),
                    onTap: { selectedBlock = block }
                )
            }
        }
    }
}
