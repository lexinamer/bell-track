import SwiftUI

struct BlockDetailView: View {
    let block: Block
    @ObservedObject var vm: TrainViewModel

    @State private var selectedWorkout: Workout?
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var editingBlock: Block?
    @State private var blockToDelete: Block?
    @State private var workoutToDelete: Workout?

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    
                    // Block metadata (static)
                    VStack(alignment: .leading, spacing: Theme.Space.xs) {
                        HStack {
                            Text(dateRangeText)
                                .font(Theme.Font.cardSecondary)
                                .foregroundColor(Color.brand.textSecondary)
                        
                            // Log workout button
//                            Spacer()
//
//                            if block.completedDate == nil {
//                                Menu {
//                                    ForEach(vm.templatesForBlock(block.id)) { template in
//                                        Button {
//                                            selectedTemplate = template
//                                        } label: {
//                                            Text(template.name)
//                                        }
//                                    }
//                                } label: {
//                                    Text("Log")
//                                        .font(Theme.Font.buttonPrimary)
//                                        .foregroundColor(Color.brand.textPrimary)
//                                        .padding(.horizontal, Theme.Space.md)
//                                        .padding(.vertical, 6)
//                                        .background(Color.brand.surface)
//                                        .clipShape(Capsule())
//                                }
//                            }
                        }

                        Text(vm.balanceFocusLabel(for: block.id))
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(Color.brand.textSecondary)
                    }

                    .padding(.horizontal)
                    .padding(.bottom, Theme.Space.xl)

                    // Template filter chips
                    TemplateFilterChips(
                        templates: vm.templatesForBlock(block.id),
                        selectedTemplateId: vm.selectedTemplateId,
                        onSelect: { templateId in
                            vm.selectTemplate(templateId)
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
                        Label("Edit Block", systemImage: "pencil")
                    }

                    if block.completedDate == nil {
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
        .onAppear {
            vm.selectBlock(block.id)
        }
    }

    // MARK: - Computed Properties
    
    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let start = formatter.string(from: block.startDate)

        // Completed
        if let completed = block.completedDate {
            let end = formatter.string(from: completed)
            return "\(start) – \(end)"
        }

        // Active with end date
        if let endDate = block.endDate {
            let end = formatter.string(from: endDate)
            return "\(weekProgressText) • Ends \(end)"
        }

        // Active ongoing (no end date)
        return "\(currentWeekOnlyText) • Started \(start)"
    }
    
    private var currentWeekOnlyText: String {
        let calendar = Calendar.current
        let week = calendar.dateComponents([.weekOfYear], from: block.startDate, to: Date()).weekOfYear ?? 0
        return "Week \(max(week + 1, 1))"
    }

    private var weekProgressText: String {
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
        guard let workoutName = workout.name else {
            return Color(hex: "27272a")
        }

        let templates = vm.templatesForBlock(block.id)

        if let index = templates.firstIndex(where: { $0.name == workoutName }) {
            return TemplateFilterChips.templateColor(for: index)
        }

        return Color(hex: "27272a")
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
}
