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
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                // Block filter chips
                blockFilterSection

                // Show content only if a block is selected
                if vm.selectedBlockId != nil {
                    // Unified block info section (date + workouts + goal) with menu
                    if let block = currentBlock {
                        blockInfoWithMenu(block: block)
                    }

                    // Template filter chips
                    templateFilterSection

                    // Workouts grouped by month
                    workoutsSection
                } else if vm.blocks.isEmpty {
                    emptyBlockState
                }
            }
            .padding(.vertical)
        }
        .background(Color.brand.background)
        .navigationTitle("Train")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if vm.activeBlock != nil {
                        ForEach(vm.activeTemplates) { template in
                            Button {
                                selectedTemplate = template
                            } label: {
                                Text(template.name)
                            }
                        }
                    }

                    Divider()

                    Button {
                        showingNewBlock = true
                    } label: {
                        Label("New Block", systemImage: "plus.square")
                    }
                } label: {
                    Image(systemName: "plus")
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

    // MARK: - Block Info with Menu

    private func blockInfoWithMenu(block: Block) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"

        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                // Date range
                if let endDate = block.endDate {
                    let start = formatter.string(from: block.startDate)
                    let end = formatter.string(from: endDate)
                    let weekText = weekProgress(for: block)
                    Text("\(start) – \(end) (\(weekText))")
                        .font(Theme.Font.cardTitle)
                        .foregroundColor(Color.brand.textPrimary)
                } else {
                    let start = formatter.string(from: block.startDate)
                    Text("Started \(start)")
                        .font(Theme.Font.cardTitle)
                        .foregroundColor(Color.brand.textPrimary)
                }

                // Workout count
                Text("\(totalWorkouts) workout\(totalWorkouts == 1 ? "" : "s")")
                    .font(Theme.Font.cardSecondary)
                    .foregroundColor(Color.brand.textSecondary)

                // Goal (if exists)
                if let notes = block.notes, !notes.isEmpty {
                    Text("Goal: \(notes)")
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(Color.brand.textSecondary)
                }
            }

            Spacer()

            Menu {
                Button {
                    Task {
                        await vm.completeBlock(id: block.id)
                    }
                } label: {
                    Label("Complete", systemImage: "checkmark.circle")
                }

                Button {
                    editingBlock = block
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    blockToDelete = block
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.brand.textSecondary)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Block Filter Section

    private var blockFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.sm) {
                // Current Block
                if let activeBlock = vm.activeBlock {
                    filterChip(
                        title: activeBlock.name,
                        isSelected: vm.selectedBlockId == activeBlock.id
                    ) {
                        vm.selectBlock(activeBlock.id)
                    }
                }

                // Past Blocks (reverse chronological)
                ForEach(vm.pastBlocks) { block in
                    let dateString = block.completedDate?.shortDateString ?? ""
                    filterChip(
                        title: "\(block.name) (\(dateString))",
                        isSelected: vm.selectedBlockId == block.id
                    ) {
                        vm.selectBlock(block.id)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func weekProgress(for block: Block) -> String {
        guard let endDate = block.endDate else { return "Ongoing" }

        let calendar = Calendar.current
        let totalWeeks = calendar.dateComponents([.weekOfYear], from: block.startDate, to: endDate).weekOfYear ?? 0
        let currentWeek = min(
            calendar.dateComponents([.weekOfYear], from: block.startDate, to: Date()).weekOfYear ?? 0,
            totalWeeks
        ) + 1

        guard totalWeeks > 0 else { return "Ongoing" }

        return "Week \(currentWeek) of \(totalWeeks + 1)"
    }



    // MARK: - Template Filter Section

    private var templateFilterSection: some View {
        Group {
            if let blockId = vm.selectedBlockId {
                let templates = vm.templatesForBlock(blockId)

                if !templates.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Space.sm) {
                            filterChip(
                                title: "All",
                                isSelected: vm.selectedTemplateId == nil
                            ) {
                                vm.selectTemplate(nil)
                            }

                            ForEach(templates) { template in
                                filterChip(
                                    title: template.name,
                                    isSelected: vm.selectedTemplateId == template.id
                                ) {
                                    vm.selectTemplate(template.id)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
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

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Font.cardSecondary)
                .padding(.horizontal, Theme.Space.md)
                .padding(.vertical, Theme.Space.sm)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(isSelected ? Color.brand.primary.opacity(0.15) : Color.brand.surfaceSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .stroke(isSelected ? Color.clear : Color.brand.border)
                )
                .foregroundColor(isSelected ? Color.brand.primary : Color.brand.textPrimary)
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
