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

    @State private var loggingTemplate: WorkoutTemplate?
    @State private var selectedWorkout: Workout?
    @State private var editingTemplate: WorkoutTemplate?
    @State private var showingNewTemplate = false
    @State private var editingBlock: Block?
    @State private var workoutToDelete: Workout?

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
                onDelete: {
                    Task {
                        await vm.deleteBlock(id: b.id)
                        editingBlock = nil
                        dismiss()
                    }
                },
                onComplete: isCompleted ? nil : {
                    Task {
                        await vm.completeBlock(id: block.id)
                        editingBlock = nil
                    }
                },
                onCancel: { editingBlock = nil }
            )
        }

        .fullScreenCover(isPresented: $showingNewTemplate) {
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

        .fullScreenCover(item: $editingTemplate) { template in
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
                    onDelete: {
                        Task {
                            await vm.deleteTemplate(id: template.id)
                            editingTemplate = nil
                        }
                    },
                    onCancel: { editingTemplate = nil }
                )
            }
        }

        // MARK: - Alerts

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
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            // Only show + when there's at least one template (force through empty state flow first)
            if !templates.isEmpty && !isCompleted {
                Menu {
                    Button { loggingTemplate = selectedTemplate ?? templates.first } label: {
                        Label("Log Workout", systemImage: "plus")
                    }
                    Button { showingNewTemplate = true } label: {
                        Label("Add Template", systemImage: "square.and.pencil")
                    }
                } label: {
                    Image(systemName: "plus").foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        ZStack(alignment: .topTrailing) {
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
            .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                Button { editingBlock = currentBlock } label: {
                    Label("Edit Block", systemImage: "square.stack.3d.up")
                }
                ForEach(Array(templates.enumerated()), id: \.element.id) { _, template in
                    Button { editingTemplate = template } label: {
                        Label("Edit \(template.name)", systemImage: "clipboard")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(Color.brand.textSecondary)
                    .padding(.leading, Theme.Space.md)
                    .padding(.bottom, Theme.Space.sm)
                    .contentShape(Rectangle())
            }
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

    // MARK: - Workouts Section

    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Filter row (only when multiple templates)
            if templates.count > 1 {
                filterRow
                    .padding(.top, Theme.Space.md)
                    .padding(.bottom, Theme.Space.lg)
            }

            if workouts.isEmpty {
                EmptyState.noWorkouts {
                    loggingTemplate = selectedTemplate ?? templates.first
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

    // MARK: - Filter Row

    private var filterRow: some View {
        HStack(alignment: .center, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.md) {
                    filterTab(label: "All", templateId: nil)
                    ForEach(templates) { template in
                        filterTab(label: template.name, templateId: template.id)
                    }
                }
                .padding(.horizontal, Theme.Space.md)
            }
            .fixedSize(horizontal: false, vertical: true)

            // Metric: total sessions when All, delta when a template is selected
            if vm.selectedTemplateId == nil {
                if let lastDate = vm.workouts.filter({ $0.blockId == block.id }).map({ $0.date }).max() {
                    Text(relativeDate(lastDate))
                        .font(Theme.Font.cardCaption)
                        .foregroundColor(Color.brand.textSecondary)
                        .padding(.bottom, Theme.Space.xs)
                        .padding(.trailing, Theme.Space.md)
                        .fixedSize()
                }
            } else if let templateId = vm.selectedTemplateId,
                      let deltaText = deltaText(for: templateId) {
                Text(deltaText)
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(deltaColor(for: templateId))
                    .padding(.bottom, Theme.Space.xs)
                    .padding(.trailing, Theme.Space.md)
                    .fixedSize()
            }
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

    // MARK: - Delta Helpers

    private func deltaText(for templateId: String) -> String? {
        let completions = vm.workouts.filter { w in
            guard let t = templates.first(where: { $0.id == templateId }) else { return false }
            return w.blockId == block.id && w.name == t.name
        }.count
        guard completions >= 2 else { return nil }

        if let delta = vm.templateVolumeDelta(templateId: templateId, blockId: block.id) {
            let abs = Swift.abs(delta)
            if delta > 0 { return "↑ \(abs) kg" }
            if delta < 0 { return "↓ \(abs) kg" }
            return "→ no change"
        }
        if let delta = vm.templateRepsDelta(templateId: templateId, blockId: block.id) {
            let abs = Swift.abs(delta)
            if delta > 0 { return "↑ \(abs) reps" }
            if delta < 0 { return "↓ \(abs) reps" }
            return "→ no change"
        }
        return nil
    }

    private func deltaColor(for templateId: String) -> Color {
        let delta = vm.templateVolumeDelta(templateId: templateId, blockId: block.id)
            ?? vm.templateRepsDelta(templateId: templateId, blockId: block.id)
        guard let delta else { return Color.brand.textSecondary }
        if delta > 0 { return Color.brand.success }
        if delta < 0 { return Color.brand.destructive }
        return Color.brand.neutral
    }

    // MARK: - Helpers

    private func relativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        switch days {
        case 0: return "Last: today"
        case 1: return "Last: yesterday"
        default: return "Last: \(days) days ago"
        }
    }

    /// The currently-selected template (from filter), nil when "All" is selected
    private var selectedTemplate: WorkoutTemplate? {
        guard let id = vm.selectedTemplateId else { return nil }
        return templates.first(where: { $0.id == id })
    }

    private func accentColor(for workout: Workout) -> Color {
        guard let index = templates.firstIndex(where: { $0.name == workout.name }) else {
            return BlockColorPalette.blockPrimary(blockIndex: blockIndex)
        }
        return BlockColorPalette.templateColor(blockIndex: blockIndex, templateIndex: index)
    }

    // MARK: - Alert Bindings

    private var deleteWorkoutBinding: Binding<Bool> {
        Binding(get: { workoutToDelete != nil }, set: { if !$0 { workoutToDelete = nil } })
    }

    private var workouts: [Workout] {
        vm.displayWorkouts.sorted { $0.date > $1.date }
    }
}
