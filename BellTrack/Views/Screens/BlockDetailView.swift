import SwiftUI

struct BlockDetailView: View {
    let block: Block
    @ObservedObject var vm: TrainViewModel
    @Environment(\.dismiss) private var dismiss

    // Live block state
    private var currentBlock: Block {
        vm.blocks.first(where: { $0.id == block.id }) ?? block
    }

    private var blockIndex: Int {
        vm.blockIndex(for: block.id)
    }

    private var templates: [WorkoutTemplate] {
        vm.templatesForBlock(block.id)
    }

    private var isCompleted: Bool {
        currentBlock.completedDate != nil
    }

    // MARK: - Local State

    @State private var selectedWorkout: Workout?
    @State private var loggingTemplate: WorkoutTemplate?
    @State private var editingTemplate: WorkoutTemplate?
    @State private var showingNewTemplate = false
    @State private var editingBlock: Block?
    @State private var blockToDelete: Block?
    @State private var workoutToDelete: Workout?
    @State private var templateToDelete: WorkoutTemplate?

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection

                    if templates.isEmpty {
                        EmptyState.noTemplates {
                            showingNewTemplate = true
                        }
                        .padding(.top, Theme.Space.xl)
                    } else {
                        templatesSection
                        workoutsSection
                    }
                }
                .padding(.top, Theme.Space.sm)
            }

        }
        .navigationTitle(currentBlock.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .onAppear { vm.selectBlock(block.id) }

        // MARK: - Covers

        .fullScreenCover(item: $loggingTemplate) { template in
            WorkoutFormView(
                workout: nil,
                template: template,
                onSave: {
                    loggingTemplate = nil
                    Task { await vm.load() }
                },
                onCancel: { loggingTemplate = nil }
            )
        }

        .fullScreenCover(item: $selectedWorkout) { workout in
            WorkoutFormView(
                workout: workout,
                onSave: {
                    selectedWorkout = nil
                    Task { await vm.load() }
                },
                onCancel: { selectedWorkout = nil }
            )
        }

        .fullScreenCover(item: $editingBlock) { b in
            BlockFormView(
                block: b,
                onSave: { name, goal, startDate, endDate in
                    Task {
                        await vm.saveBlock(id: b.id, name: name, goal: goal, startDate: startDate, endDate: endDate)
                        editingBlock = nil
                    }
                },
                onCancel: { editingBlock = nil }
            )
        }

        .sheet(isPresented: $showingNewTemplate) {
            NavigationStack {
                WorkoutTemplateFormView(
                    exercises: vm.exercises,
                    onSave: { name, entries in
                        Task {
                            await vm.saveTemplate(id: nil, name: name, blockId: block.id, entries: entries)
                            showingNewTemplate = false
                        }
                    },
                    onCancel: { showingNewTemplate = false }
                )
            }
        }

        .sheet(item: $editingTemplate) { template in
            NavigationStack {
                WorkoutTemplateFormView(
                    template: template,
                    exercises: vm.exercises,
                    onSave: { name, entries in
                        Task {
                            await vm.saveTemplate(id: template.id, name: name, blockId: block.id, entries: entries)
                            editingTemplate = nil
                        }
                    },
                    onCancel: { editingTemplate = nil }
                )
            }
        }

        // MARK: - Alerts

        .alert("Delete Block?", isPresented: deleteBlockBinding) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let b = blockToDelete {
                    Task {
                        await vm.deleteBlock(id: b.id)
                        dismiss()
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
                    Task { await vm.deleteWorkout(id: workout.id) }
                }
            }
        } message: {
            Text("This will permanently delete this workout.")
        }

        .alert("Delete Template?", isPresented: deleteTemplateBinding) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let template = templateToDelete {
                    Task { await vm.deleteTemplate(id: template.id) }
                }
            }
        } message: {
            Text("This will permanently delete \"\(templateToDelete?.name ?? "")\".")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { editingBlock = currentBlock } label: {
                    Label("Edit Block", systemImage: "square.and.pencil")
                }
                if !isCompleted {
                    Button {
                        Task { await vm.completeBlock(id: block.id) }
                    } label: {
                        Label("Mark as Complete", systemImage: "checkmark.circle")
                    }
                }
                Button(role: .destructive) { blockToDelete = currentBlock } label: {
                    Label("Delete Block", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis").foregroundColor(.white)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            if let goal = currentBlock.goal, !goal.isEmpty {
                Text(goal)
                    .font(Theme.Font.cardSecondary)
                    .foregroundColor(Color.brand.textSecondary)
            }

            Text(progressLineText)
                .font(Theme.Font.cardCaption)
                .foregroundColor(Color.brand.textSecondary)
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.bottom, Theme.Space.lg)
    }

    private var progressLineText: String {
        if let endDate = currentBlock.endDate {
            let cal = Calendar.current
            let totalWeeks = cal.dateComponents([.weekOfYear], from: currentBlock.startDate, to: endDate).weekOfYear ?? 0
            let currentWeek = min(
                cal.dateComponents([.weekOfYear], from: currentBlock.startDate, to: Date()).weekOfYear ?? 0,
                totalWeeks
            ) + 1
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            return "Week \(currentWeek) of \(totalWeeks) · Ends \(f.string(from: endDate))"
        }
        return "Ongoing"
    }

    // MARK: - Templates Section

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            SectionDivider(title: "Templates")

            VStack(spacing: Theme.Space.sm) {
                ForEach(Array(templates.enumerated()), id: \.element.id) { templateIndex, template in
                    TemplateCard(
                        template: template,
                        completionCount: completionCount(for: template),
                        volumeDelta: volumeDelta(for: template),
                        accentColor: BlockColorPalette.templateColor(
                            blockIndex: blockIndex,
                            templateIndex: templateIndex
                        ),
                        onLog: !isCompleted ? { loggingTemplate = template } : nil,
                        onEdit: { editingTemplate = template },
                        onDelete: { templateToDelete = template }
                    )
                    .padding(.horizontal, Theme.Space.md)
                }
                
                if !isCompleted {
                    addTemplateChip
                }
            }
        }
        .padding(.bottom, Theme.Space.md)
    }

    // MARK: - Workouts Section
    
    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: 0) {

            SectionDivider(title: "Workouts")

            if templates.count > 1 {
                filterTabs
                    .padding(.bottom, Theme.Space.md)
            }

            if workouts.isEmpty {
                EmptyState.noWorkouts {
                    loggingTemplate = templates.first
                }
                .padding(.top, Theme.Space.lg)
                .padding(.horizontal, Theme.Space.md)
            } else {
                VStack(spacing: Theme.Space.sm) {
                    ForEach(workouts) { workout in
                        WorkoutCard(
                            workout: workout,
                            exercises: vm.exercises,
                            accentColor: accentColor(for: workout),
                            onEdit: { selectedWorkout = workout },
                            onDelete: { workoutToDelete = workout }
                        )
                        .padding(.horizontal, Theme.Space.md)
                    }
                }
            }
        }
        .padding(.bottom, Theme.Space.xl)
    }

    // MARK: - Add Template Chip
    
    private var addTemplateChip: some View {
        Button {
            showingNewTemplate = true
        } label: {
            Label("Add Template", systemImage: "plus")
                .font(Theme.Font.cardCaption.weight(.medium))
                .foregroundColor(Color.brand.textSecondary)
                .padding(.horizontal, Theme.Space.sm)
                .padding(.vertical, Theme.Space.xs)
                .background(Color.brand.surface)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Space.md)
        .padding(.top, Theme.Space.xs)
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.md) {
                filterTab(label: "All", templateId: nil)
                ForEach(templates) { template in
                    filterTab(label: template.name, templateId: template.id)
                }
            }
            .padding(.horizontal, Theme.Space.md)
        }
    }

    private func filterTab(label: String, templateId: String?) -> some View {
        let isSelected = vm.selectedTemplateId == templateId
        return Button {
            vm.selectTemplate(templateId)
        } label: {
            Text(label)
                .font(Theme.Font.cardSecondary.weight(isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? Color.brand.textPrimary : Color.brand.textPrimary.opacity(0.5))
                .padding(.bottom, Theme.Space.xs)
                .overlay(alignment: .bottom) {
                    if isSelected {
                        Rectangle()
                            .fill(Color.brand.textPrimary)
                            .frame(height: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: vm.selectedTemplateId)
    }

    // MARK: - Helpers

    private func accentColor(for workout: Workout) -> Color {
        guard let index = templates.firstIndex(where: { $0.name == workout.name }) else {
            return BlockColorPalette.blockPrimary(blockIndex: blockIndex)
        }
        return BlockColorPalette.templateColor(blockIndex: blockIndex, templateIndex: index)
    }

    private func completionCount(for template: WorkoutTemplate) -> Int {
        vm.workouts.filter { $0.blockId == block.id && $0.name == template.name }.count
    }

    private func volumeDelta(for template: WorkoutTemplate) -> Int? {
        guard let stats = vm.templateVolumeStats(templateId: template.id) else { return nil }
        guard stats.last > 0 && completionCount(for: template) >= 2 else { return nil }
        return stats.last - (vm.workouts
            .filter { $0.blockId == block.id && $0.name == template.name }
            .sorted { $0.date > $1.date }
            .dropFirst()
            .first
            .map { workout in
                Int(workout.logs.reduce(0.0) { total, log in
                    let sets = Double(log.sets ?? 0)
                    let reps = Double(log.reps ?? "0") ?? 0
                    let base = Double(log.weight ?? "0") ?? 0
                    let weight = log.isDouble ? base * 2 : base
                    let mode = vm.exercises.first(where: { $0.id == log.exerciseId })?.mode ?? .reps
                    return (weight > 0 && reps > 0 && mode != .time) ? total + sets * reps * weight : total
                })
            } ?? 0)
    }

    // MARK: - Alert Bindings

    private var deleteBlockBinding: Binding<Bool> {
        Binding(get: { blockToDelete != nil }, set: { if !$0 { blockToDelete = nil } })
    }

    private var deleteWorkoutBinding: Binding<Bool> {
        Binding(get: { workoutToDelete != nil }, set: { if !$0 { workoutToDelete = nil } })
    }

    private var deleteTemplateBinding: Binding<Bool> {
        Binding(get: { templateToDelete != nil }, set: { if !$0 { templateToDelete = nil } })
    }
    
    private var workouts: [Workout] {
        vm.displayWorkouts.sorted { $0.date > $1.date }
    }

    private var hasWorkouts: Bool {
        !workouts.isEmpty
    }
}
