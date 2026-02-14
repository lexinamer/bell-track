import SwiftUI

struct AllBlocksView: View {

    @ObservedObject var blocksVM: BlocksViewModel

    @State private var showingNewBlock = false
    @State private var selectedBlock: Block?
    @State private var editingBlock: Block?
    @State private var blockToDelete: Block?

    // MARK: - Groups

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

                    if blocksVM.blocks.isEmpty {
                        emptyState
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("All Blocks")
        .navigationDestination(item: $selectedBlock) {
            BlockDetailView(block: $0)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNewBlock = true
                } label: {
                    Label("New Block", systemImage: "plus")
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .fullScreenCover(isPresented: $showingNewBlock) {
            BlockFormView(
                blocksVM: blocksVM,
                onSave: { name, start, type, duration, notes, color in
                    Task {

                        await blocksVM.saveBlock(
                            id: nil,
                            name: name,
                            startDate: start,
                            type: type,
                            durationWeeks: duration,
                            notes: notes,
                            colorIndex: color
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
                blocksVM: blocksVM,
                onSave: { name, startDate, type, durationWeeks, notes, colorIndex in
                    Task {
                        await blocksVM.saveBlock(
                            id: block.id,
                            name: name,
                            startDate: startDate,
                            type: type,
                            durationWeeks: durationWeeks,
                            notes: notes,
                            colorIndex: colorIndex
                        )
                        editingBlock = nil
                    }
                },
                onCancel: {
                    editingBlock = nil
                }
            )
        }
        .alert(
            "Delete Block?",
            isPresented: deleteBinding
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
    }

    // MARK: - Section

    private func section(
        title: String,
        blocks: [Block]
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(title)
                .font(Theme.Font.sectionTitle)
                .padding(.horizontal)
            LazyVStack(spacing: Theme.Space.sm) {
                ForEach(blocks) { block in
                    BlockCard(
                        block: block,
                        workoutCount: blocksVM.workoutCounts[block.id],
                        templateCount: blocksVM.templatesForBlock(block.id).count,
                        onEdit: {
                            editingBlock = block
                        },
                        onComplete: {},
                        onDelete: {
                            blockToDelete = block
                        }
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
        VStack(spacing: Theme.Space.md) {
            Image(systemName: "square.stack")
                .font(.system(size: Theme.IconSize.xl))
                .foregroundColor(.secondary)
            Text("No blocks yet")
                .font(Theme.Font.emptyStateTitle)
            Text("Create your first training block.")
                .font(Theme.Font.emptyStateDescription)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.xl)
    }

    // MARK: - Binding

    private var deleteBinding: Binding<Bool> {
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
