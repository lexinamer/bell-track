import SwiftUI

struct TrainView: View {
    @StateObject private var vm = TrainViewModel()
    @State private var selectedBlock: Block?
    @State private var showingNewBlock = false
    @State private var showingLogWorkout = false
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var editingBlock: Block?
    @State private var blockToDelete: Block?

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
                EmptyStateNoActiveBlock(action: { showingNewBlock = true })

            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        Button { showingNewBlock = true } label: {
                            Label("New Block", systemImage: "square.stack.3d.up")
                                .font(Theme.Font.cardCaption)
                                .foregroundColor(Color.brand.primary)
                        }
                        .padding(.top, Theme.Space.sm)
                        .padding(.bottom, Theme.Space.md)

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
                Button { showingLogWorkout = true } label: {
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
                exercises: vm.exercises,
                onSave: { name, goal, start, endDate, templates in
                    Task {
                        if let newBlockId = await vm.saveBlock(
                            id: nil,
                            name: name,
                            goal: goal,
                            startDate: start,
                            endDate: endDate
                        ) {
                            for template in templates {
                                await vm.saveTemplate(
                                    id: nil,
                                    name: template.name,
                                    blockId: newBlockId,
                                    entries: template.entries,
                                    workoutType: template.workoutType,
                                    duration: template.duration
                                )
                            }
                            await vm.load()
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
        .fullScreenCover(item: $editingBlock) { b in
            BlockFormView(
                block: b,
                existingTemplates: vm.templatesForBlock(b.id),
                exercises: vm.exercises,
                onSave: { name, goal, startDate, endDate, templates in
                    Task {
                        await vm.saveBlock(id: b.id, name: name, goal: goal, startDate: startDate, endDate: endDate)
                        let existingIds = Set(vm.templatesForBlock(b.id).map { $0.id })
                        for template in templates {
                            await vm.saveTemplate(
                                id: existingIds.contains(template.id) ? template.id : nil,
                                name: template.name,
                                blockId: b.id,
                                entries: template.entries,
                                workoutType: template.workoutType,
                                duration: template.duration
                            )
                        }
                        let updatedIds = Set(templates.map { $0.id })
                        for template in vm.templatesForBlock(b.id) where !updatedIds.contains(template.id) {
                            await vm.deleteTemplate(id: template.id)
                        }
                        editingBlock = nil
                    }
                },
                onCancel: { editingBlock = nil }
            )
        }
        .alert("Delete Block?", isPresented: Binding(
            get: { blockToDelete != nil },
            set: { if !$0 { blockToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let b = blockToDelete {
                    Task { await vm.deleteBlock(id: b.id) }
                    blockToDelete = nil
                }
            }
        } message: {
            Text("This will permanently delete \"\(blockToDelete?.name ?? "")\".")
        }
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
                    onTap: { selectedBlock = block },
                    onEdit: { editingBlock = block },
                    onDelete: { blockToDelete = block },
                    onComplete: { Task { await vm.completeBlock(id: block.id) } }
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
                    onTap: { selectedBlock = block },
                    onEdit: { editingBlock = block },
                    onDelete: { blockToDelete = block },
                    onComplete: nil
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
                    onTap: { selectedBlock = block },
                    onEdit: { editingBlock = block },
                    onDelete: { blockToDelete = block },
                    onComplete: nil
                )
            }
        }
    }
}
