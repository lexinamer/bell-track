import SwiftUI

struct TrainView: View {

    @StateObject private var vm = TrainViewModel()

    // Navigation
    @State private var selectedWorkout: Workout?
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var showingNewBlock = false
    @State private var editingBlock: Block?
    @State private var blockToDelete: Block?

    // Toggle between Current and All
    @State private var viewMode: ViewMode = .current

    enum ViewMode {
        case current
        case all
    }

    // MARK: - Stats

    private var totalWorkouts: Int {
        viewMode == .current
            ? vm.totalWorkouts(for: vm.activeBlock?.id)
            : vm.totalWorkouts(for: vm.selectedBlockId)
    }

    private var totalSets: Int {
        viewMode == .current
            ? vm.totalSets(for: vm.activeBlock?.id)
            : vm.totalSets(for: vm.selectedBlockId)
    }

    private var totalVolume: Double {
        viewMode == .current
            ? vm.totalVolume(for: vm.activeBlock?.id)
            : vm.totalVolume(for: vm.selectedBlockId)
    }

    private var displayWorkouts: [Workout] {
        viewMode == .current
            ? vm.activeBlockWorkouts
            : vm.filteredWorkouts
    }

    // MARK: - View

    var body: some View {
        TabView(selection: $viewMode) {
            currentView
                .tag(ViewMode.current)

            allView
                .tag(ViewMode.all)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(Color.brand.background)
        .navigationTitle(viewMode == .current ? "Current" : "All")
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
                } else {
                    Button {
                        showingNewBlock = true
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
        .task {
            await vm.load()
        }
    }

    // MARK: - Current View

    private var currentView: some View {
        ScrollView {
            if let block = vm.activeBlock {
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    // Block Info
                    blockInfoSection(block: block)

                    // Stats Cards
                    statsSection

                    // Balance Score
                    balanceScoreSection

                    // Templates
                    if !vm.activeTemplates.isEmpty {
                        templatesSection
                    }

                    // Workouts
                    if !vm.activeBlockWorkouts.isEmpty {
                        workoutsSection
                    } else {
                        emptyWorkoutsState
                    }
                }
                .padding(.vertical)
            } else {
                emptyBlockState
            }
        }
    }

    // MARK: - All View

    private var allView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                // Filter dropdown
                filterSection

                // Stats
                statsSection

                // All workouts
                if !displayWorkouts.isEmpty {
                    workoutsSection
                } else {
                    emptyWorkoutsState
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Block Info Section

    private func blockInfoSection(block: Block) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text(block.name)
                        .font(Theme.Font.pageTitle)
                        .foregroundColor(Color.brand.textPrimary)

                    // Date range with week progress
                    if let endDate = block.endDate {
                        let start = block.startDate.shortDateString
                        let end = endDate.shortDateString
                        let weekText = weekProgress(for: block)
                        Text("\(start) – \(end) (\(weekText))")
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(Color.brand.textSecondary)
                    } else {
                        Text("Started \(block.startDate.shortDateString)")
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(Color.brand.textSecondary)
                    }

                    // Goal (notes field)
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
        }
        .padding(.horizontal)
    }

    // Helper to calculate week progress
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

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: Theme.Space.md) {
            statCard(title: "Workouts", value: "\(totalWorkouts)")
            statCard(title: "Sets", value: "\(totalSets)")
            statCard(title: "Volume", value: String(format: "%.0f", totalVolume))
        }
        .padding(.horizontal)
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(title)
                .font(Theme.Font.cardCaption)
                .foregroundColor(Color.brand.textSecondary)

            Text(value)
                .font(Theme.Font.statValue)
                .foregroundColor(Color.brand.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.md)
        .background(Color.brand.surface)
        .cornerRadius(Theme.Radius.md)
    }

    // MARK: - Balance Score Section

    private var balanceScoreSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text("Balance Score")
                .font(Theme.Font.sectionTitle)
                .foregroundColor(Color.brand.textPrimary)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                HStack {
                    Text("\(vm.balanceScore)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(vm.balanceScoreColor)

                    Spacer()
                }

                Text("Top 3 Muscles")
                    .font(Theme.Font.cardSecondary)
                    .foregroundColor(Color.brand.textSecondary)
                    .padding(.top, Theme.Space.xs)

                ForEach(vm.topThreeMuscles) { stat in
                    HStack {
                        Text(stat.muscle.displayName)
                            .font(Theme.Font.cardTitle)
                            .foregroundColor(Color.brand.textPrimary)

                        Spacer()

                        Text("\(Int(round(stat.percent * 100)))%")
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(Color.brand.textSecondary)
                    }
                }

                Button {
                    // TODO: Navigate to full muscle breakdown
                } label: {
                    Text("View detailed breakdown")
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(Color.brand.primary)
                }
                .padding(.top, Theme.Space.xs)
            }
            .padding(Theme.Space.md)
            .background(Color.brand.surface)
            .cornerRadius(Theme.Radius.md)
            .padding(.horizontal)
        }
    }

    // MARK: - Templates Section

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("Templates")
                .font(Theme.Font.sectionTitle)
                .foregroundColor(Color.brand.textPrimary)
                .padding(.horizontal)

            ForEach(vm.activeTemplates) { template in
                Button {
                    selectedTemplate = template
                } label: {
                    HStack {
                        Text(template.name)
                            .font(Theme.Font.cardTitle)
                            .foregroundColor(Color.brand.textPrimary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(Color.brand.textSecondary)
                    }
                    .padding(Theme.Space.md)
                    .background(Color.brand.surface)
                    .cornerRadius(Theme.Radius.md)
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Workouts Section

    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("Workouts")
                .font(Theme.Font.sectionTitle)
                .foregroundColor(Color.brand.textPrimary)
                .padding(.horizontal)

            ForEach(displayWorkouts) { workout in
                WorkoutCard(workout: workout)
                    .padding(.horizontal)
                    .onTapGesture {
                        selectedWorkout = workout
                    }
            }
        }
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.sm) {
                filterChip(
                    title: "All",
                    isSelected: vm.selectedBlockId == nil
                ) {
                    vm.selectBlock(nil)
                }

                ForEach(vm.filteredBlocks.prefix(5)) { block in
                    filterChip(
                        title: block.name,
                        isSelected: vm.selectedBlockId == block.id
                    ) {
                        vm.selectBlock(block.id)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Font.cardSecondary)
                .padding(.horizontal, Theme.Space.md)
                .padding(.vertical, Theme.Space.xs)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(isSelected ? Color.brand.primary.opacity(0.15) : Color.clear)
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
                    .foregroundColor(.white)
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
}
