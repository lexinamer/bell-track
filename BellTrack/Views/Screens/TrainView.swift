import SwiftUI

struct TrainView: View {
    @StateObject private var vm = TrainViewModel()
    @State private var selectedBlock: Block?
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var showingNewBlock = false
    @State private var showingLogWorkout = false
    @State private var editingWorkout: Workout?
    @State private var workoutToDelete: Workout?

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            if vm.isLoading {
                VStack {
                    Spacer()
                    ProgressView().padding()
                    Spacer()
                }
                .frame(maxWidth: .infinity)

            } else if vm.activeBlocks.isEmpty && vm.pastBlocks.isEmpty {
                EmptyState.noActiveBlock { showingNewBlock = true }

            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // Active blocks
                        activeBlocksSection(vm.activeBlocks)

                        // Completed blocks
                        if !vm.pastBlocks.isEmpty {
                            Rectangle()
                                .fill(Color.brand.textSecondary.opacity(0.15))
                                .frame(height: 1)
                                .padding(.vertical, Theme.Space.xxl)
                            completedBlocksSection(vm.pastBlocks)
                        }
                    }
                    .padding(.top, Theme.Space.md)
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.bottom, 60)
                }
            }
        }
        .navigationTitle("Train")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showingLogWorkout = true } label: {
                        Label("Log Workout", systemImage: "plus.circle")
                    }
                    Button { showingNewBlock = true } label: {
                        Label("Create New Block", systemImage: "square.stack.3d.up")
                    }
                } label: {
                    Image(systemName: "plus").foregroundColor(.white)
                }
            }
        }
        .navigationDestination(item: $selectedBlock) {
            BlockDetailView(block: $0, vm: vm)
        }
        .fullScreenCover(isPresented: $showingLogWorkout) {
            WorkoutFormView(
                workout: nil,
                template: nil,
                onSave: {
                    showingLogWorkout = false
                    Task { await vm.load() }
                },
                onCancel: { showingLogWorkout = false }
            )
        }
        .fullScreenCover(item: $selectedTemplate) { template in
            WorkoutFormView(
                workout: nil,
                template: template,
                onSave: {
                    selectedTemplate = nil
                    Task { await vm.load() }
                },
                onCancel: { selectedTemplate = nil }
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
                onCancel: { showingNewBlock = false }
            )
        }
        .fullScreenCover(item: $editingWorkout) { workout in
            WorkoutFormView(
                workout: workout,
                onSave: {
                    editingWorkout = nil
                    Task { await vm.load() }
                },
                onCancel: { editingWorkout = nil }
            )
        }
        .alert("Delete Workout?", isPresented: Binding(
            get: { workoutToDelete != nil },
            set: { if !$0 { workoutToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let w = workoutToDelete {
                    Task { await vm.deleteWorkout(id: w.id) }
                }
            }
        } message: {
            Text("This will permanently delete this workout.")
        }
        .task { await vm.load() }
    }

    // MARK: Active Blocks

    private func activeBlocksSection(_ blocks: [Block]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                activeBlockSection(block)
                if index < blocks.count - 1 {
                    Spacer().frame(height: Theme.Space.xl)
                }
            }
        }
    }

    private func activeBlockSection(_ block: Block) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {

            Button {
                selectedBlock = block
            } label: {
                HStack {
                    Text(block.name)
                        .font(Theme.Font.navigationTitle)
                        .foregroundColor(Color.brand.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.brand.textSecondary)
                }
                .padding(.trailing, Theme.Space.md)
            }
            .buttonStyle(.plain)

            Text("\(weekProgress(for: block)) • \(vm.balanceFocusLabel(for: block.id))")
                .font(Theme.Font.cardCaption)
                .foregroundColor(Color.brand.textSecondary)

            let workouts = vm.recentWorkouts(for: block.id, limit: 3)

            if workouts.isEmpty {
                Text("No workouts yet")
                    .font(Theme.Font.cardSecondary)
                    .foregroundColor(Color.brand.textSecondary)
                    .padding(.top, Theme.Space.md)
            } else {
                VStack(spacing: Theme.Space.sm) {
                    ForEach(workouts) { workout in
                        WorkoutCard(
                            workout: workout,
                            exercises: vm.exercises,
                            badgeColor: BlockColorPalette.templateColor(
                                blockIndex: vm.blockIndex(for: block.id),
                                templateIndex: vm.templatesForBlock(block.id)
                                    .firstIndex(where: { $0.name == workout.name }) ?? 0
                            ),
                            onEdit: { editingWorkout = workout },
                            onDelete: { workoutToDelete = workout }
                        )
                    }
                }
                .padding(.top, Theme.Space.md)
            }
        }
    }

    // MARK: Completed Blocks (Card Style)

    private func completedBlocksSection(_ blocks: [Block]) -> some View {
        VStack(spacing: Theme.Space.md) {
            ForEach(blocks) { block in
                completedBlockCard(block)
            }
        }
    }

    private func completedBlockCard(_ block: Block) -> some View {
        Button {
            selectedBlock = block
        } label: {
            HStack(spacing: 0) {
                // Accent bar — TrainView.swift ~line 190. Remove this HStack wrapper to remove the bar.
                Rectangle()
                    .fill(BlockColorPalette.blockPrimary(blockIndex: vm.blockIndex(for: block.id)))
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: Theme.Space.xs) {

                    HStack {
                        Text(block.name)
                            .font(Theme.Font.sectionTitle)
                            .foregroundColor(Color.brand.textPrimary)

                        Spacer()

                        Text("COMPLETED")
                            .font(Theme.Font.cardBadge)
                            .foregroundColor(Color.brand.textPrimary.opacity(0.85))
                            .padding(.horizontal, Theme.Space.sm)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.brand.textSecondary.opacity(0.2))
                            )
                    }

                    Text("\(blockSubtitle(for: block)) • \(vm.balanceFocusLabel(for: block.id))")
                        .font(Theme.Font.cardCaption)
                        .foregroundColor(Color.brand.textSecondary)
                }
                .padding(Theme.Space.md)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.brand.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .opacity(0.9)
        }
        .buttonStyle(.plain)
    }

    // MARK: Helpers

    private func weekProgress(for block: Block) -> String {
        guard let endDate = block.endDate else { return "Ongoing" }
        let cal = Calendar.current
        let total = cal.dateComponents([.weekOfYear], from: block.startDate, to: endDate).weekOfYear ?? 0
        let current = min(cal.dateComponents([.weekOfYear], from: block.startDate, to: Date()).weekOfYear ?? 0, total) + 1
        guard total > 0 else { return "Ongoing" }
        return "Week \(current) of \(total + 1)"
    }
    
    private func blockSubtitle(for block: Block) -> String {
        if let completedDate = block.completedDate {
            return dateRangeString(from: block.startDate, to: completedDate)
        } else {
            return weekProgress(for: block)
        }
    }

    private func dateRangeString(from start: Date, to end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

}
