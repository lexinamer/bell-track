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
    @State private var filteredTemplateId: String?

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
                    } else if workouts.isEmpty {
                        EmptyState.noWorkouts(
                            logAction: {
                                loggingTemplate = templates.first
                            },
                            createTemplateAction: {
                                showingNewTemplate = true
                            }
                        )
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
            WorkoutTemplateFormView(
                exercises: vm.exercises,
                onSave: { name, entries, workoutType, duration in
                    Task {
                        await vm.saveTemplate(id: nil, name: name, blockId: block.id, entries: entries, workoutType: workoutType, duration: duration)
                        showingNewTemplate = false
                    }
                },
                onCancel: { showingNewTemplate = false }
            )
        }

        .fullScreenCover(item: $editingTemplate) { template in
            WorkoutTemplateFormView(
                template: template,
                exercises: vm.exercises,
                onSave: { name, entries, workoutType, duration in
                    Task {
                        await vm.saveTemplate(id: template.id, name: name, blockId: block.id, entries: entries, workoutType: workoutType, duration: duration)
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
            Menu {
                Button { loggingTemplate = templates.first } label: {
                    Label("Log Workout", systemImage: "plus")
                }
                Button { showingNewTemplate = true } label: {
                    Label("Add Template", systemImage: "square.and.pencil")
                }
            } label: {
                Image(systemName: "plus")
                    .foregroundColor(.white)
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
                    .padding(.trailing, Theme.Space.sm)
                    .padding(.bottom, Theme.Space.sm)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.bottom, Theme.Space.sm)
    }

    private var progressLineText: String {
        if isCompleted {
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            let start = f.string(from: currentBlock.startDate)
            let end = f.string(from: currentBlock.completedDate ?? currentBlock.endDate ?? currentBlock.startDate)
            return "\(start) – \(end)"
        }
        if currentBlock.startDate > Date() {
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            return "Not started · Starts \(f.string(from: currentBlock.startDate))"
        }
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
        let cal = Calendar.current
        let current = (cal.dateComponents([.weekOfYear], from: currentBlock.startDate, to: Date()).weekOfYear ?? 0) + 1
        return "Week \(current) · Ongoing"
    }

    // MARK: - Workouts Section

    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: 0) {

            if !metricsLineParts.isEmpty {
                HStack(spacing: Theme.Space.xl) {
                    ForEach(metricsLineParts, id: \.templateId) { part in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                filteredTemplateId = filteredTemplateId == part.templateId ? nil : part.templateId
                            }
                        } label: {
                            HStack(spacing: Theme.Space.xs) {
                                if let name = part.name {
                                    Text(name)
                                        .foregroundColor(Color.brand.textSecondary)
                                }
                                Text(part.delta)
                                    .foregroundColor(part.color)
                            }
                            .opacity(filteredTemplateId == nil || filteredTemplateId == part.templateId ? 1.0 : 0.35)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .font(Theme.Font.cardCaption)
                .padding(.horizontal, Theme.Space.md)
                .padding(.top, Theme.Space.md)
                .padding(.bottom, Theme.Space.lg)
            }

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
        .padding(.bottom, Theme.Space.xl)
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
            if delta > 0 { return "↑\(abs)kg" }
            if delta < 0 { return "↓\(abs)kg" }
            return "→ no change"
        }
        if let delta = vm.templateRepsDelta(templateId: templateId, blockId: block.id) {
            let abs = Swift.abs(delta)
            if delta > 0 { return "↑\(abs) reps" }
            if delta < 0 { return "↓\(abs) reps" }
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

    private var metricsLineParts: [(templateId: String, name: String?, delta: String, color: Color)] {
        templates.compactMap { template in
            guard let text = deltaText(for: template.id) else { return nil }
            let color = deltaColor(for: template.id)
            let name: String? = templates.count > 1 ? template.name : nil
            return (template.id, name, text, color)
        }
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
        var all = vm.workouts.filter { $0.blockId == block.id }
        if let id = filteredTemplateId,
           let name = templates.first(where: { $0.id == id })?.name {
            all = all.filter { $0.name == name }
        }
        return all.sorted { $0.date > $1.date }
    }
}
