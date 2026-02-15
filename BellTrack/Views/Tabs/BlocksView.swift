import SwiftUI

struct BlocksView: View {

    @StateObject private var blocksVM = BlocksViewModel()

    // Navigation
    @State private var selectedBlock: Block?

    // Sheets
    @State private var showingNewBlock = false
    @State private var showingNewWorkout = false
    @State private var editingBlock: Block?
    @State private var blockToDelete: Block?

    // MARK: - Derived

    private var activeBlocks: [Block] {
        blocksVM.blocks
            .filter {
                $0.completedDate == nil &&
                $0.startDate <= Date()
            }
            .sorted { $0.startDate > $1.startDate }
    }

    private var futureBlocks: [Block] {
        blocksVM.blocks
            .filter {
                $0.completedDate == nil &&
                $0.startDate > Date()
            }
            .sorted { $0.startDate < $1.startDate }
    }

    private var completedBlocks: [Block] {
        blocksVM.blocks
            .filter { $0.completedDate != nil }
            .sorted {
                ($0.completedDate ?? .distantPast)
                >
                ($1.completedDate ?? .distantPast)
            }
    }

    // MARK: - View

    var body: some View {

        ZStack {

            Color.brand.background
                .ignoresSafeArea()

            if blocksVM.isLoading && blocksVM.blocks.isEmpty {

                ProgressView()

            } else if blocksVM.blocks.isEmpty {

                emptyState

            } else {

                ScrollView {

                    LazyVStack(
                        alignment: .leading,
                        spacing: Theme.Space.xl
                    ) {

                        if !activeBlocks.isEmpty {
                            section(
                                title: "Active",
                                blocks: activeBlocks
                            )
                        }

                        if !futureBlocks.isEmpty {
                            section(
                                title: "Planned",
                                blocks: futureBlocks
                            )
                        }

                        if !completedBlocks.isEmpty {
                            section(
                                title: "Completed",
                                blocks: completedBlocks
                            )
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("Blocks")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingNewWorkout = true
                    } label: {
                        Label("Log Workout", systemImage: "figure.run")
                    }

                    Button {
                        showingNewBlock = true
                    } label: {
                        Label("Create Block", systemImage: "square.stack.3d.up")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(item: $selectedBlock) {
            BlockDetailView(block: $0, blocksVM: blocksVM)
        }

        // MARK: - New Block Sheet

        .fullScreenCover(isPresented: $showingNewBlock) {

            BlockFormView(
                blocksVM: blocksVM,
                onSave: { name, start, endDate, notes, _, pendingTemplates in

                    Task {

                        await blocksVM.saveBlock(
                            id: nil,
                            name: name,
                            startDate: start,
                            endDate: endDate,
                            notes: notes,
                            colorIndex: nil,
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

        // MARK: - Edit Block Sheet

        .fullScreenCover(item: $editingBlock) { block in

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
                        editingBlock = nil
                    }
                },
                onCancel: {
                    editingBlock = nil
                }
            )
        }

        // MARK: - New Workout Sheet

        .fullScreenCover(isPresented: $showingNewWorkout) {

            WorkoutFormView(
                workout: nil,
                onSave: {
                    showingNewWorkout = false
                    Task { await blocksVM.load() }
                },
                onCancel: {
                    showingNewWorkout = false
                }
            )
        }

        // MARK: - Delete Block Alert

        .alert(
            "Delete Block?",
            isPresented: deleteBlockBinding
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let block = blockToDelete {
                    Task {
                        await blocksVM.deleteBlock(id: block.id)
                    }
                }
            }
        } message: {
            Text(
                "This will permanently delete \"\(blockToDelete?.name ?? "")\"."
            )
        }

        // MARK: - Load

        .task {
            await blocksVM.load()
        }
    }

    // MARK: - Section

    private func section(
        title: String,
        blocks: [Block]
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(title)
                .font(Theme.Font.sectionTitle)
                .foregroundColor(Color.brand.textPrimary)
                .padding(.horizontal)
                
            LazyVStack(spacing: Theme.Space.sm) {
                ForEach(blocks) { block in
                    BlockCard(
                        block: block,
                        workoutCount: blocksVM.workoutCounts[block.id],
                        templateCount: blocksVM.templatesForBlock(block.id).count
                    )
                    .padding(.horizontal)
                    .onTapGesture {
                        selectedBlock = block
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {

        VStack(spacing: Theme.Space.lg) {

            Spacer()

            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 44))
                .foregroundColor(Color.brand.textSecondary)

            Text("Start your training")
                .font(Theme.Font.emptyStateTitle)
                .foregroundColor(Color.brand.textPrimary)

            Text("Create a block to organize your training, then log workouts.")
                .font(Theme.Font.emptyStateDescription)
                .foregroundColor(Color.brand.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Space.lg)

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

    // MARK: - Binding

    private var deleteBlockBinding: Binding<Bool> {
        Binding(
            get: { blockToDelete != nil },
            set: {
                if !$0 {
                    blockToDelete = nil
                }
            }
        )
    }
}
