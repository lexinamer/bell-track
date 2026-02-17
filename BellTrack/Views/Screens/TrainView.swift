import SwiftUI

struct TrainView: View {

    @StateObject private var vm = TrainViewModel()

    @State private var selectedWorkout: Workout?
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var showingNewBlock = false
    @State private var editingBlock: Block?
    @State private var blockToDelete: Block?
    @State private var workoutToDelete: Workout?
    @State private var showingBlockSelector = false
    @State private var showingCompletedBlockSelector = false
    @State private var currentPage = 0
    @State private var selectedCompletedBlockId: String?

    // MARK: - View

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if vm.isLoading {
                    VStack(spacing: Theme.Space.lg) {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else if vm.activeBlocks.isEmpty {
                    EmptyState.noActiveBlock {
                        showingNewBlock = true
                    }
                } else {
                    VStack(spacing: 0) {
                        if isViewingCompletedBlock {
                            TrainHeader(
                                blockName: displayedCompletedBlock?.name ?? "",
                                isCompleted: true,
                                showCompletedBadge: displayedCompletedBlock?.completedDate != nil,
                                onTap: {
                                    showingCompletedBlockSelector = true
                                }
                            )
                        } else {
                            TrainHeader(
                                blockName: currentPage < vm.activeBlocks.count ? vm.activeBlocks[currentPage].name : ""
                            )
                        }

                        TabView(selection: $currentPage) {
                            // Active blocks
                            ForEach(Array(vm.activeBlocks.enumerated()), id: \.element.id) { index, block in
                                blockPageContent(block: block, isCompleted: false)
                                    .tag(index)
                            }

                            // Last completed block
                            if let completedBlock = displayedCompletedBlock {
                                blockPageContent(block: completedBlock, isCompleted: true)
                                    .tag(vm.activeBlocks.count)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .always))
                        .indexViewStyle(.page(backgroundDisplayMode: .always))
                        .onChange(of: currentPage) { oldValue, newValue in
                            if newValue < vm.activeBlocks.count {
                                vm.selectBlock(vm.activeBlocks[newValue].id)
                            } else if let completedBlock = displayedCompletedBlock {
                                vm.selectBlock(completedBlock.id)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button {
                        showingNewBlock = true
                    } label: {
                        Label("New Block", systemImage: "plus")
                    }

                    Button {
                        if let block = currentDisplayedBlock {
                            editingBlock = block
                        }
                    } label: {
                        Label("Edit Block", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        if let block = currentDisplayedBlock {
                            blockToDelete = block
                        }
                    } label: {
                        Label("Delete Block", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.white)
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                if !vm.activeBlocks.isEmpty && !isViewingCompletedBlock {
                    // Log workout button (only show for active blocks)
                    Menu {
                        ForEach(vm.allActiveTemplates) { template in
                            Button {
                                selectedTemplate = template
                            } label: {
                                Text(template.name)
                            }
                        }
                    } label: {
                        Text("Log")
                            .font(Theme.Font.buttonPrimary)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
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
        .fullScreenCover(item: $selectedWorkout) { workout in
            WorkoutFormView(
                workout: workout,
                onSave: {
                    selectedWorkout = nil
                    Task { await vm.load() }
                },
                onCancel: {
                    selectedWorkout = nil
                }
            )
        }
        .fullScreenCover(isPresented: $showingNewBlock) {
            BlockFormView(
                vm: vm,
                onSave: { name, start, endDate, pendingTemplates in
                    Task {
                        await vm.saveBlock(
                            id: nil,
                            name: name,
                            startDate: start,
                            endDate: endDate,
                            pendingTemplates: pendingTemplates
                        )
                        showingNewBlock = false
                    }
                },
                onCancel: {
                    showingNewBlock = false
                }
            )
        }
        .fullScreenCover(item: $editingBlock) { block in
            BlockFormView(
                block: block,
                vm: vm,
                onSave: { name, startDate, endDate, pendingTemplates in
                    Task {
                        await vm.saveBlock(
                            id: block.id,
                            name: name,
                            startDate: startDate,
                            endDate: endDate
                        )
                        editingBlock = nil
                    }
                },
                onCancel: {
                    editingBlock = nil
                }
            )
        }
        .alert("Delete Block?", isPresented: deleteBlockBinding) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let block = blockToDelete {
                    Task {
                        await vm.deleteBlock(id: block.id)
                    }
                }
            }
        } message: {
            Text("This will permanently delete \"\(blockToDelete?.name ?? "")\".")
        }
        .alert("Delete Workout?", isPresented: deleteWorkoutBinding) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let workout = workoutToDelete {
                    Task {
                        await vm.deleteWorkout(id: workout.id)
                    }
                }
            }
        } message: {
            Text("This will permanently delete this workout.")
        }
        .sheet(isPresented: $showingBlockSelector) {
            BlockSelectorView(
                activeBlocks: vm.activeBlocks,
                pastBlocks: vm.pastBlocks,
                selectedBlockId: vm.selectedBlockId,
                onSelect: { block in
                    vm.selectBlock(block.id)
                    showingBlockSelector = false
                },
                onEdit: { block in
                    editingBlock = block
                    showingBlockSelector = false
                },
                onComplete: { block in
                    Task {
                        await vm.completeBlock(id: block.id)
                    }
                    showingBlockSelector = false
                },
                onDelete: { block in
                    blockToDelete = block
                    showingBlockSelector = false
                },
                onDismiss: {
                    showingBlockSelector = false
                }
            )
        }
        .sheet(isPresented: $showingCompletedBlockSelector) {
            BlockSelectorView(
                activeBlocks: [],
                pastBlocks: vm.pastBlocks,
                selectedBlockId: selectedCompletedBlockId,
                completedBlocksOnly: true,
                onSelect: { block in
                    selectedCompletedBlockId = block.id
                    vm.selectBlock(block.id)
                    showingCompletedBlockSelector = false
                },
                onEdit: { _ in },
                onDelete: { _ in },
                onDismiss: {
                    showingCompletedBlockSelector = false
                }
            )
        }
        .task {
            await vm.load()
            // Set current page to match selected block
            if let selectedId = vm.selectedBlockId,
               let index = vm.activeBlocks.firstIndex(where: { $0.id == selectedId }) {
                currentPage = index
            }
        }
    }

    // MARK: - Computed

    private var currentBlock: Block? {
        if let selectedId = vm.selectedBlockId {
            return vm.blocks.first { $0.id == selectedId }
        }
        return nil
    }

    private var displayedCompletedBlock: Block? {
        if let selectedId = selectedCompletedBlockId {
            return vm.pastBlocks.first { $0.id == selectedId }
        }
        return vm.pastBlocks.first
    }

    private var isViewingCompletedBlock: Bool {
        currentPage == vm.activeBlocks.count
    }

    private var currentDisplayedBlock: Block? {
        if isViewingCompletedBlock {
            return displayedCompletedBlock
        } else if currentPage < vm.activeBlocks.count {
            return vm.activeBlocks[currentPage]
        }
        return nil
    }

    // MARK: - Block Page Content

    private func blockPageContent(block: Block, isCompleted: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BlockInfo(
                    block: block,
                    balanceFocusLabel: vm.balanceFocusLabel,
                    onTap: {
                        showingBlockSelector = true
                    }
                )
                .padding(.horizontal)
                .padding(.bottom, Theme.Space.xl)

                TemplateFilterChips(
                    templates: vm.templatesForBlock(block.id),
                    selectedTemplateId: vm.selectedTemplateId,
                    onSelect: { templateId in
                        vm.selectTemplate(templateId)
                    }
                )
                .padding(.bottom, Theme.Space.lg)

                workoutsSection
            }
            .padding(.vertical, Theme.Space.md)
        }
    }


    // MARK: - Workouts Section

    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            let groupedWorkouts = vm.groupedWorkoutsByMonth(vm.displayWorkouts)

            if groupedWorkouts.isEmpty {
                VStack(spacing: Theme.Space.md) {
                    Text("No workouts yet")
                        .font(Theme.Font.cardTitle)
                        .foregroundColor(Color.brand.textSecondary)
                        .padding(.horizontal)
                }
                .padding(.vertical, Theme.Space.xl)
            } else {
                ForEach(groupedWorkouts, id: \.month) { group in
                    VStack(alignment: .leading, spacing: Theme.Space.md) {
//                        Text(group.month)
//                            .font(Theme.Font.cardSecondary)
//                            .foregroundColor(Color.brand.textSecondary)
//                            .padding(.horizontal)

                        ForEach(group.workouts) { workout in
                            WorkoutCard(
                                workout: workout,
                                exercises: vm.exercises,
                                badgeColor: badgeColorForWorkout(workout),
                                onEdit: { selectedWorkout = workout },
                                onDelete: { workoutToDelete = workout }
                            )
                            .padding(.horizontal)
                        }
                    }
                }
            }
        }
    }

    private func badgeColorForWorkout(_ workout: Workout) -> Color {
        guard let blockId = vm.selectedBlockId,
              let workoutName = workout.name else {
            return Color(hex: "27272a")
        }

        let templates = vm.templatesForBlock(blockId)

        if let index = templates.firstIndex(where: { $0.name == workoutName }) {
            return TemplateFilterChips.templateColor(for: index)
        }

        return Color(hex: "27272a")
    }

    // MARK: - Binding

    private var deleteBlockBinding: Binding<Bool> {
        Binding(
            get: { blockToDelete != nil },
            set: { if !$0 { blockToDelete = nil } }
        )
    }

    private var deleteWorkoutBinding: Binding<Bool> {
        Binding(
            get: { workoutToDelete != nil },
            set: { if !$0 { workoutToDelete = nil } }
        )
    }
}
