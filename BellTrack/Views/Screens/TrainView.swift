import SwiftUI

struct TrainView: View {

    @StateObject private var vm = TrainViewModel()

    // Navigation
    @State private var selectedWorkout: Workout?
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var showingNewBlock = false
    @State private var editingBlock: Block?
    @State private var blockToDelete: Block?
    @State private var workoutToDelete: Workout?
    @State private var showingProgramSelector = false
    @State private var showingFilter = false

    // MARK: - Stats

    private var totalWorkouts: Int {
        vm.totalWorkouts(for: vm.selectedBlockId)
    }

    private var totalSets: Int {
        vm.totalSets(for: vm.selectedBlockId)
    }

    private var totalVolume: Double {
        vm.totalVolume(for: vm.selectedBlockId)
    }

    // MARK: - View

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                // Show content only if a block is selected
                if let block = currentBlock {
                    // 1. Program Selector
                    ProgramSelector(block: block) {
                        showingProgramSelector = true
                    }
                    .padding(.horizontal)

                    // 2. Progress Summary Card
                    if !vm.muscleBalance.isEmpty || vm.volumeTrend != nil {
                        ProgressSummaryCard(
                            muscleBalance: vm.muscleBalance,
                            volumeTrend: vm.volumeTrend
                        )
                        .padding(.horizontal)
                    }

                    // 3. Workouts Header with Filter
                    workoutsHeader

                    // 4. Workouts grouped by month
                    workoutsSection
                } else if vm.blocks.isEmpty {
                    emptyBlockState
                }
            }
            .padding(.vertical, Theme.Space.md)
        }
        .background(Color.brand.background)
        .navigationTitle("Train")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if vm.activeBlock != nil {
                    Menu {
                        ForEach(vm.activeTemplates) { template in
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
                onSave: { name, start, endDate, notes, pendingTemplates in
                    Task {
                        await vm.saveBlock(
                            id: nil,
                            name: name,
                            startDate: start,
                            endDate: endDate,
                            notes: notes,
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
                onSave: { name, startDate, endDate, notes, pendingTemplates in
                    Task {
                        await vm.saveBlock(
                            id: block.id,
                            name: name,
                            startDate: startDate,
                            endDate: endDate,
                            notes: notes
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
        .sheet(isPresented: $showingProgramSelector) {
            programSelectorSheet
        }
        .sheet(isPresented: $showingFilter) {
            if let blockId = vm.selectedBlockId {
                WorkoutFilterSheet(
                    templates: vm.templatesForBlock(blockId),
                    selectedTemplateId: vm.selectedTemplateId,
                    onSelectTemplate: { templateId in
                        vm.selectTemplate(templateId)
                    }
                )
            }
        }
        .task {
            await vm.load()
        }
    }

    // MARK: - Computed

    private var currentBlock: Block? {
        if let selectedId = vm.selectedBlockId {
            return vm.blocks.first { $0.id == selectedId }
        }
        return nil
    }


    // MARK: - Workouts Section

    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            let groupedWorkouts = vm.groupedWorkoutsByMonth(vm.displayWorkouts)

            if groupedWorkouts.isEmpty {
                emptyWorkoutsState
            } else {
                ForEach(groupedWorkouts, id: \.month) { group in
                    VStack(alignment: .leading, spacing: Theme.Space.sm) {
                        Text(group.month)
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(Color.brand.textSecondary)
                            .padding(.horizontal)

                        ForEach(group.workouts) { workout in
                            WorkoutCard(
                                workout: workout,
                                onEdit: {
                                    selectedWorkout = workout
                                },
                                onDelete: {
                                    workoutToDelete = workout
                                }
                            )
                            .padding(.horizontal)
                        }
                    }
                }
            }
        }
    }


    // MARK: - Empty States

    private var emptyBlockState: some View {
        VStack(spacing: Theme.Space.lg) {
            Spacer()

            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 44))
                .foregroundColor(Color.brand.textSecondary)

            Text("No active block")
                .font(Theme.Font.emptyStateTitle)
                .foregroundColor(Color.brand.textPrimary)

            Text("Create a block to start training")
                .font(Theme.Font.emptyStateDescription)
                .foregroundColor(Color.brand.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                showingNewBlock = true
            } label: {
                Text("Create Block")
                    .font(Theme.Font.buttonPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Space.sm)
                    .background(Color.brand.primary)
                    .foregroundColor(Color.brand.background)
                    .cornerRadius(Theme.Radius.md)
            }
            .padding(.horizontal, Theme.Space.xl)

            Spacer()
        }
    }

    private var emptyWorkoutsState: some View {
        VStack(spacing: Theme.Space.md) {
            Text("No workouts yet")
                .font(Theme.Font.cardTitle)
                .foregroundColor(Color.brand.textSecondary)
                .padding(.horizontal)
        }
        .padding(.vertical, Theme.Space.xl)
    }

    // MARK: - Workouts Header

    private var workoutsHeader: some View {
        HStack {
            Text("Workouts")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.brand.textPrimary)

            Spacer()

            if let blockId = vm.selectedBlockId, !vm.templatesForBlock(blockId).isEmpty {
                Button(action: {
                    showingFilter = true
                }) {
                    HStack(spacing: 6) {
                        if let templateId = vm.selectedTemplateId,
                           let template = vm.templates.first(where: { $0.id == templateId }) {
                            Text(template.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.brand.primary)
                        } else {
                            Text("Filter")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.brand.textSecondary)
                        }

                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 16))
                            .foregroundColor(Color.brand.textSecondary)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Program Selector Sheet

    private var programSelectorSheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Current Block
                if let activeBlock = vm.activeBlock {
                    blockSelectorOption(
                        block: activeBlock,
                        isSelected: vm.selectedBlockId == activeBlock.id,
                        isCurrent: true
                    )

                    if !vm.pastBlocks.isEmpty {
                        Divider()
                            .padding(.leading, Theme.Space.md)
                    }
                }

                // Past Blocks
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(vm.pastBlocks) { block in
                            blockSelectorOption(
                                block: block,
                                isSelected: vm.selectedBlockId == block.id,
                                isCurrent: false
                            )

                            if block.id != vm.pastBlocks.last?.id {
                                Divider()
                                    .padding(.leading, Theme.Space.md)
                            }
                        }
                    }
                }
            }
            .background(Color.brand.background)
            .navigationTitle("Select Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingProgramSelector = false
                    }
                    .foregroundColor(Color.brand.primary)
                }
            }
        }
    }

    private func blockSelectorOption(block: Block, isSelected: Bool, isCurrent: Bool) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"

        return Button(action: {
            vm.selectBlock(block.id)
            showingProgramSelector = false
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Theme.Space.sm) {
                        Text(block.name)
                            .font(Theme.Font.cardTitle)
                            .foregroundColor(Color.brand.textPrimary)

                        if isCurrent {
                            Text("ACTIVE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.brand.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.brand.primary.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }

                    if let completedDate = block.completedDate {
                        Text("Completed \(completedDate.shortDateString)")
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(Color.brand.textSecondary)
                    } else {
                        let startText = formatter.string(from: block.startDate)
                        Text("Started \(startText)")
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(Color.brand.textSecondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.brand.primary)
                }
            }
            .padding(Theme.Space.md)
            .background(Color.brand.background)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
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
