import SwiftUI

struct BlockDetailView: View {

    let block: Block
    @ObservedObject var blocksVM: BlocksViewModel

    @StateObject private var workoutsVM = WorkoutsViewModel()
    @Environment(\.dismiss) private var dismiss

    // MARK: - Actions

    @State private var showingEdit = false
    @State private var showingDeleteAlert = false
    @State private var showingCompleteAlert = false
    @State private var editingWorkout: Workout?
    @State private var workoutToDelete: Workout?

    // MARK: - Filtering

    @State private var selectedTemplateId: String? = nil

    // MARK: - Derived

    private var templates: [WorkoutTemplate] {
        blocksVM.templatesForBlock(block.id)
    }

    private var allWorkouts: [Workout] {
        workoutsVM.workouts(for: block.id)
    }

    private var filteredWorkouts: [Workout] {
        guard let templateId = selectedTemplateId else {
            return allWorkouts
        }

        // Filter workouts by template name
        guard let template = templates.first(where: { $0.id == templateId }) else {
            return allWorkouts
        }

        return allWorkouts.filter { $0.name == template.name }
    }

    private var totalWorkouts: Int {
        allWorkouts.count
    }

    private var totalSets: Int {
        allWorkouts
            .flatMap { $0.logs }
            .compactMap { $0.sets }
            .reduce(0, +)
    }

    private var weekProgressText: String? {
        guard let endDate = block.endDate else { return nil }

        let calendar = Calendar.current
        let totalWeeks = calendar.dateComponents([.weekOfYear], from: block.startDate, to: endDate).weekOfYear ?? 0
        let currentWeek = min(
            calendar.dateComponents([.weekOfYear], from: block.startDate, to: Date()).weekOfYear ?? 0,
            totalWeeks
        ) + 1

        guard totalWeeks > 0 else { return nil }

        return "Week \(currentWeek) of \(totalWeeks + 1)"
    }

    // MARK: - View

    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: Theme.Space.lg
            ) {

                headerSection

                statsRow

                if !templates.isEmpty {
                    templatesSection
                }

                workoutsSection
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, Theme.Space.md)
        }
        .background(Color.brand.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarMenu }
        .task {
            await workoutsVM.load()
        }

        // MARK: - Edit Workout Sheet

        .fullScreenCover(item: $editingWorkout) { workout in
            WorkoutFormView(
                workout: workout,
                onSave: {
                    editingWorkout = nil
                    Task { await workoutsVM.load() }
                },
                onCancel: {
                    editingWorkout = nil
                }
            )
        }

        // MARK: - Edit Block Sheet

        .fullScreenCover(isPresented: $showingEdit) {
            BlockFormView(
                block: block,
                blocksVM: blocksVM,
                onSave: { name, startDate, endDate, notes, _, _ in
                    Task {
                        await blocksVM.saveBlock(
                            id: block.id,
                            name: name,
                            startDate: startDate,
                            endDate: endDate,
                            notes: notes,
                            colorIndex: nil
                        )
                        showingEdit = false
                    }
                },
                onCancel: {
                    showingEdit = false
                }
            )
        }

        // MARK: - Delete Workout Alert

        .alert("Delete Workout?", isPresented: Binding(
            get: { workoutToDelete != nil },
            set: { if !$0 { workoutToDelete = nil } }
        )) {

            Button("Cancel", role: .cancel) {}

            Button("Delete", role: .destructive) {
                if let workout = workoutToDelete {
                    Task {
                        await workoutsVM.deleteWorkout(id: workout.id)
                        await workoutsVM.load()
                    }
                }
            }

        } message: {
            Text("This will permanently delete this workout.")
        }

        // MARK: - Delete Block Alert

        .alert("Delete Block?", isPresented: $showingDeleteAlert) {

            Button("Cancel", role: .cancel) { }

            Button("Delete", role: .destructive) {
                Task {
                    await blocksVM.deleteBlock(id: block.id)
                    dismiss()
                }
            }

        } message: {
            Text("This cannot be undone.")
        }

        // MARK: - Complete Block Alert

        .alert("Complete Block?", isPresented: $showingCompleteAlert) {

            Button("Cancel", role: .cancel) { }

            Button("Complete") {
                Task {
                    await blocksVM.completeBlock(id: block.id)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {

        VStack(alignment: .leading, spacing: Theme.Space.sm) {

            Text(block.name)
                .font(Theme.Font.pageTitle)
                .foregroundColor(Color.brand.textPrimary)

            Text(progressText)
                .font(Theme.Font.cardSecondary)
                .foregroundColor(Color.brand.textSecondary)

            if let weekProgress = weekProgressText {
                Text(weekProgress)
                    .font(Theme.Font.cardSecondary)
                    .foregroundColor(Color.brand.textSecondary)
            }

            if let goal = block.notes, !goal.isEmpty {
                Text("\(Text("Goal: ").fontWeight(.semibold))\(Text(goal))")
                    .font(Theme.Font.cardSecondary)
                    .foregroundColor(Color.brand.textSecondary)
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {

        HStack(spacing: 0) {

            statItem(value: totalWorkouts, label: "Workouts")

            Divider()
                .frame(height: 32)

            statItem(value: totalSets, label: "Total Sets")
        }
        .padding(.vertical, Theme.Space.smp)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .fill(Color.brand.surface)
        )
    }

    private func statItem(value: Int, label: String) -> some View {
        VStack(spacing: Theme.Space.xs) {
            Text("\(value)")
                .font(Theme.Font.statValue)
                .foregroundColor(Color.brand.textPrimary)

            Text(label)
                .font(Theme.Font.statLabel)
                .foregroundColor(Color.brand.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Templates Section

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {

            Text("Templates")
                .font(Theme.Font.sectionTitle)
                .foregroundColor(Color.brand.textPrimary)

            VStack(spacing: 0) {
                ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in

                    let isSelected = selectedTemplateId == template.id
                    let lastPerformed = lastPerformedDate(for: template)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selectedTemplateId == template.id {
                                selectedTemplateId = nil
                            } else {
                                selectedTemplateId = template.id
                            }
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(Theme.Font.cardTitle)
                                    .foregroundColor(Color.brand.textPrimary)

                                if let lastDate = lastPerformed {
                                    Text("Last: \(lastDate)")
                                        .font(Theme.Font.cardCaption)
                                        .foregroundColor(Color.brand.textSecondary)
                                } else {
                                    Text("Not performed yet")
                                        .font(Theme.Font.cardCaption)
                                        .foregroundColor(Color.brand.textSecondary)
                                }
                            }

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color.brand.primary)
                            }
                        }
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.vertical, Theme.Space.sm)
                        .background(isSelected ? Color.brand.primary.opacity(0.1) : Color.clear)
                    }

                    if index < templates.count - 1 {
                        Divider()
                            .padding(.leading, Theme.Space.md)
                    }
                }
            }
            .background(Color.brand.surface)
            .cornerRadius(Theme.Radius.md)
        }
    }

    private func lastPerformedDate(for template: WorkoutTemplate) -> String? {
        let templateWorkouts = allWorkouts.filter { $0.name == template.name }
        guard let latest = templateWorkouts.max(by: { $0.date < $1.date }) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: latest.date)
    }

    // MARK: - Workouts Section

    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {

            HStack {
                Text(selectedTemplateId == nil ? "All Workouts" : "Filtered Workouts")
                    .font(Theme.Font.sectionTitle)
                    .foregroundColor(Color.brand.textPrimary)

                if selectedTemplateId != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTemplateId = nil
                        }
                    } label: {
                        Text("Clear")
                            .font(Theme.Font.cardCaption)
                            .foregroundColor(Color.brand.primary)
                    }
                }
            }

            if filteredWorkouts.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: Theme.Space.sm) {
                    ForEach(filteredWorkouts) { workout in
                        WorkoutCard(
                            workout: workout,
                            badgeColor: Color.brand.blockColor,
                            onEdit: {
                                editingWorkout = workout
                            },
                            onDelete: {
                                workoutToDelete = workout
                            }
                        )
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Space.sm) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: Theme.IconSize.lg))
                .foregroundColor(Color.brand.textSecondary)
            Text(selectedTemplateId == nil ? "No workouts yet" : "No workouts found")
                .font(Theme.Font.emptyStateTitle)
                .foregroundColor(Color.brand.textPrimary)
            Text(selectedTemplateId == nil ?
                "Workouts assigned to this block will appear here." :
                "No workouts logged with this template."
            )
                .font(Theme.Font.emptyStateDescription)
                .foregroundColor(Color.brand.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.lg)
    }

    // MARK: - Toolbar Menu

    private var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    showingEdit = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                if block.completedDate == nil {
                    Button {
                        showingCompleteAlert = true
                    } label: {
                        Label("Complete", systemImage: "checkmark.circle")
                    }
                }
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
        }
    }

    // MARK: - Progress Text

    private var progressText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let start = formatter.string(from: block.startDate)

        if let endDate = block.endDate {
            let end = formatter.string(from: endDate)
            return "\(start) – \(end)"
        } else {
            return "Started \(start)"
        }
    }
}
