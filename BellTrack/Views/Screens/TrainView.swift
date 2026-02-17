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
    @State private var showingBlockSelector = false

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
            VStack(alignment: .leading, spacing: 0) {
                // Show content only if a block is selected
                if vm.isLoading {
                    VStack(spacing: Theme.Space.lg) {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else if let block = currentBlock {
                    // 1. Block Selector with Muscle Balance
                    blockSelector(block: block)
                        .padding(.horizontal)
                        .padding(.bottom, Theme.Space.xl)

                    // 2. Template Filter Chips
                    templateFilterChips(blockId: block.id)
                        .padding(.bottom, Theme.Space.lg)

                    // 3. Workouts grouped by month
                    workoutsSection
                } else if vm.blocks.isEmpty {
                    emptyBlockState
                }
            }
            .padding(.vertical, Theme.Space.md)
        }
        .background(Color.brand.background)
        .navigationTitle(currentBlock?.name ?? "")
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
        .toolbarTitleMenu {
            ForEach(vm.blocks) { block in
                Button {
                    vm.selectBlock(block.id)
                } label: {
                    HStack {
                        Text(block.name)
                        if block.id == vm.selectedBlockId {
                            Image(systemName: "checkmark")
                        }
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
            blockSelectorSheet
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
                                exercises: vm.exercises,
                                badgeColor: badgeColorForWorkout(workout),
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

    private func badgeColorForWorkout(_ workout: Workout) -> Color {
        guard let blockId = vm.selectedBlockId,
              let workoutName = workout.name else {
            return Color(hex: "27272a")
        }

        let templates = vm.templatesForBlock(blockId)

        if let index = templates.firstIndex(where: { $0.name == workoutName }) {
            return templateColor(index: index)
        }

        return Color(hex: "27272a")
    }


    // MARK: - Empty States

    private var emptyBlockState: some View {
        VStack(spacing: Theme.Space.lg) {
            Spacer()

            Image(systemName: "square.stack.3d.up")
                .font(Theme.Font.pageTitle)
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

    // MARK: - Template Filter Chips

    private func templateFilterChips(blockId: String) -> some View {
        let templates = vm.templatesForBlock(blockId)

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.sm) {
                // Template chips
                ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                    let isSelected = vm.selectedTemplateId == template.id

                    filterChip(
                        title: template.name,
                        isSelected: isSelected,
                        color: templateColor(index: index),
                        action: {
                            if isSelected {
                                vm.selectTemplate(nil) // deselect → show all
                            } else {
                                vm.selectTemplate(template.id) // select template
                            }
                        }
                    )
                }

            }
            .padding(.horizontal)
        }
    }

    private func filterChip(title: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Font.cardTitle)
                .foregroundColor(.white)
                .padding(.horizontal, Theme.Space.lg)
                .padding(.vertical, 12)
                .background(color)
                .cornerRadius(Theme.Radius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg)
                        .inset(by: 0.5)
                        .stroke(.white.opacity(0.8), lineWidth: isSelected ? 1.5 : 0)
                )
        }
    }

    private func templateColor(index: Int) -> Color {
        let colors = [
            Color(hex: "A64DFF"),
            Color(hex: "962EFF"),
            Color(hex: "8000FF"),
            Color(hex: "6900D1")
        ]
        return colors[index % colors.count]
    }

    // MARK: - Block Selector Sheet

    private var blockSelectorSheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Current Block
                if let activeBlock = vm.activeBlock {
                    blockSelectorOption(
                        block: activeBlock,
                        isSelected: vm.selectedBlockId == activeBlock.id,
                        isCurrent: true
                    )

                    Divider()
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

                            Divider()
                        }
                    }
                }
            }
            .background(Color.brand.background)
            .navigationTitle("Select Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingBlockSelector = false
                    }
                    .foregroundColor(Color.brand.textPrimary)
                }
            }
        }
    }

    private func blockSelectorOption(block: Block, isSelected: Bool, isCurrent: Bool) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"

        return HStack(spacing: 0) {
            Button(action: {
                vm.selectBlock(block.id)
                showingBlockSelector = false
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: Theme.Space.sm) {
                            Text(block.name)
                                .font(Theme.Font.cardTitle)
                                .foregroundColor(Color.brand.textPrimary)

                            if isCurrent {
                                Text("ACTIVE")
                                    .font(Theme.Font.statLabel)
                                    .foregroundColor(Color.brand.primary)
                                    .padding(.horizontal, Theme.Space.sm)
                                    .padding(.vertical, 2)
                                    .background(Color.brand.primary.opacity(0.15))
                                    .cornerRadius(Theme.Radius.xs)
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
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            Menu {
                Button {
                    editingBlock = block
                    showingBlockSelector = false
                } label: {
                    Label("Edit Block", systemImage: "pencil")
                }

                if block.completedDate == nil {
                    Button {
                        Task {
                            await vm.completeBlock(id: block.id)
                        }
                        showingBlockSelector = false
                    } label: {
                        Label("Complete Block", systemImage: "checkmark.circle")
                    }
                }

                Button(role: .destructive) {
                    blockToDelete = block
                    showingBlockSelector = false
                } label: {
                    Label("Delete Block", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundColor(Color.brand.textSecondary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.vertical, Theme.Space.sm)
        .background(Color.brand.background)
    }

    // MARK: - Volume Summary

    private func volumeSummary(best: Int, last: Int) -> some View {
        HStack(spacing: Theme.Space.lg) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Best")
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(Color.brand.textSecondary)
                Text("\(best) kg")
                    .font(Theme.Font.cardTitle)
                    .foregroundColor(Color.brand.textPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Last")
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(Color.brand.textSecondary)
                Text("\(last) kg")
                    .font(Theme.Font.cardTitle)
                    .foregroundColor(Color.brand.textPrimary)
            }

            Spacer()
        }
    }

    // MARK: - Block Selector

    private func blockSelector(block: Block) -> some View {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"

        let dateRangeText: String = {
            if let endDate = block.endDate {
                let end = dateFormatter.string(from: endDate)
                return "Ends \(end)"
            } else {
                let start = dateFormatter.string(from: block.startDate)
                return "Started \(start)"
            }
        }()

        let weekProgressText: String = {
            guard let endDate = block.endDate else { return "Ongoing" }

            let calendar = Calendar.current
            let totalWeeks = calendar.dateComponents([.weekOfYear], from: block.startDate, to: endDate).weekOfYear ?? 0
            let currentWeek = min(
                calendar.dateComponents([.weekOfYear], from: block.startDate, to: Date()).weekOfYear ?? 0,
                totalWeeks
            ) + 1

            guard totalWeeks > 0 else { return "Ongoing" }

            return "Week \(currentWeek) of \(totalWeeks + 1)"
        }()

        return Button(action: {
            showingBlockSelector = true
        }) {
            HStack(alignment: .top, spacing: Theme.Space.md) {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text("\(weekProgressText) • \(dateRangeText)")
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(Color.brand.textSecondary)

                    Text(vm.balanceFocusLabel)
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(Color.brand.textSecondary)
                }

                Spacer()

                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundColor(Color.brand.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
