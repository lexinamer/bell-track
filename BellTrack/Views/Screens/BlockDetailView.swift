import SwiftUI

struct BlockDetailView: View {
    let block: Block
    @ObservedObject var vm: TrainViewModel
    @Environment(\.dismiss) private var dismiss

    // Live block state — reflects updates (e.g. after completing)
    private var currentBlock: Block {
        vm.blocks.first(where: { $0.id == block.id }) ?? block
    }

    @State private var selectedWorkout: Workout?
    @State private var loggingTemplate: WorkoutTemplate?
    @State private var filterTemplateId: String?
    @State private var editingBlock: Block?
    @State private var blockToDelete: Block?
    @State private var workoutToDelete: Workout?

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    
                    // Block metadata (static)
                    HStack(alignment: .center) {
                        let workoutCount = vm.workouts.filter { $0.blockId == block.id }.count

                        VStack(alignment: .leading, spacing: 2) {
                            Text(dateRangeText)
                                .font(Theme.Font.cardSecondary)
                                .foregroundColor(Color.brand.textSecondary)

                            Text("\(workoutCount) \(workoutCount == 1 ? "workout" : "workouts") (\(vm.balanceFocusLabel(for: block.id)))")
                                .font(Theme.Font.cardSecondary)
                                .foregroundColor(Color.brand.textSecondary)
                        }

                        Spacer()

                        if currentBlock.completedDate == nil {
                            Menu {
                                ForEach(vm.templatesForBlock(block.id)) { template in
                                    Button {
                                        loggingTemplate = template
                                    } label: {
                                        Text(template.name)
                                    }
                                }
                            } label: {
                                HStack(spacing: Theme.Space.sm) {
                                    Image(systemName: "plus")
                                    Text("Log")
                                }
                                .font(Theme.Font.cardCaption)
                            }
                            .buttonStyle(.bordered)
                            .tint(.white)
                        }
                    }

                    .padding(.horizontal)
                    .padding(.bottom, Theme.Space.xl)

                    // Template filter chips
                    TemplateFilterChips(
                        blockIndex: vm.blockIndex(for: block.id),
                        templates: vm.templatesForBlock(block.id),
                        selectedTemplateId: filterTemplateId,
                        onSelect: { id in
                            filterTemplateId = id
                            vm.selectTemplate(id)
                        }
                    )
                    .padding(.bottom, Theme.Space.lg)

                    // Full workout cards
                    workoutsSection
                }
                .padding(.vertical, Theme.Space.md)
            }
        }
        .navigationTitle(block.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            // "..." menu with actions
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        editingBlock = block
                    } label: {
                        Label("Edit Block", systemImage: "square.and.pencil")
                    }

                    if currentBlock.completedDate == nil {
                        Button {
                            Task {
                                await vm.completeBlock(id: block.id)
                            }
                        } label: {
                            Label("Mark as Complete", systemImage: "checkmark.circle")
                        }
                    }

                    Button(role: .destructive) {
                        blockToDelete = block
                    } label: {
                        Label("Delete Block", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.white)
                }
            }
        }
        .fullScreenCover(item: $loggingTemplate) { template in
            WorkoutFormView(
                workout: nil,
                template: template,
                onSave: {
                    loggingTemplate = nil
                    Task { await vm.load() }
                },
                onCancel: {
                    loggingTemplate = nil
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
                    Task {
                        await vm.deleteWorkout(id: workout.id)
                    }
                }
            }
        } message: {
            Text("This will permanently delete this workout.")
        }
        .onAppear {
            vm.selectBlock(block.id)
        }
    }

    // MARK: - Computed Properties
    
    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let start = formatter.string(from: currentBlock.startDate)

        // Completed
        if let completed = currentBlock.completedDate {
            let end = formatter.string(from: completed)
            return "\(start) – \(end)"
        }

        // Active with end date
        if let endDate = currentBlock.endDate {
            let end = formatter.string(from: endDate)
            return "\(weekProgressText) • Ends \(end)"
        }

        // Active ongoing (no end date)
        return "\(currentWeekOnlyText) • Started \(start)"
    }

    private var currentWeekOnlyText: String {
        let calendar = Calendar.current
        let week = calendar.dateComponents([.weekOfYear], from: currentBlock.startDate, to: Date()).weekOfYear ?? 0
        return "Week \(max(week + 1, 1))"
    }

    private var weekProgressText: String {
        guard let endDate = currentBlock.endDate else { return "Ongoing" }

        let calendar = Calendar.current
        let totalWeeks = calendar.dateComponents([.weekOfYear], from: currentBlock.startDate, to: endDate).weekOfYear ?? 0
        let currentWeek = min(
            calendar.dateComponents([.weekOfYear], from: currentBlock.startDate, to: Date()).weekOfYear ?? 0,
            totalWeeks
        ) + 1

        guard totalWeeks > 0 else { return "Ongoing" }

        return "Week \(currentWeek) of \(totalWeeks)"
    }

    // MARK: - Workouts Section

    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            let groupedWorkouts = vm.groupedWorkoutsByMonth(vm.displayWorkouts)

            if groupedWorkouts.isEmpty {
                VStack(spacing: Theme.Space.md) {
                    Text("No workouts yet")
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(Color.brand.textSecondary)
                }
                .padding(.vertical, Theme.Space.md)
                .padding(.horizontal, Theme.Space.md)
            } else {
                ForEach(groupedWorkouts, id: \.month) { group in
                    VStack(alignment: .leading, spacing: Theme.Space.md) {
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

    // MARK: - Bindings

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
    
    private func badgeColorForWorkout(_ workout: Workout) -> Color {
        let templates = vm.templatesForBlock(block.id)
        let blockIdx = vm.blockIndex(for: block.id)

        guard let index = templates.firstIndex(where: { $0.name == workout.name })
        else { return BlockColorPalette.blockPrimary(blockIndex: blockIdx) }

        return BlockColorPalette.templateColor(blockIndex: blockIdx, templateIndex: index)
    }
}
