import SwiftUI

struct CompletedBlocksView: View {

    @ObservedObject var blocksVM: BlocksViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editingBlock: Block? = nil
    @State private var blockToDelete: Block? = nil

    private var completedBlocks: [Block] {
        blocksVM.blocks
            .filter { $0.completedDate != nil }
            .sorted { ($0.completedDate ?? .distantPast) > ($1.completedDate ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brand.background
                    .ignoresSafeArea()

                if completedBlocks.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.Space.md) {
                            ForEach(completedBlocks) { block in
                                completedBlockCard(block)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, Theme.Space.sm)
                    }
                }
            }
            .navigationTitle("Completed Blocks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            // Edit sheet
            .sheet(item: $editingBlock) { block in
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
                    onCancel: { editingBlock = nil }
                )
            }
            // Delete confirmation
            .alert("Delete Block?", isPresented: .init(
                get: { blockToDelete != nil },
                set: { if !$0 { blockToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) { blockToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let block = blockToDelete {
                        Task { await blocksVM.deleteBlock(id: block.id) }
                    }
                    blockToDelete = nil
                }
            } message: {
                Text("This will permanently delete \"\(blockToDelete?.name ?? "")\". Workouts assigned to this block will not be deleted.")
            }
        }
    }

    // MARK: - Completed Block Card

    private func completedBlockCard(_ block: Block) -> some View {
        SimpleCard {
            HStack(spacing: Theme.Space.smp) {
                // Color indicator bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(ColorTheme.blockColor(for: block.colorIndex))
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    // Block name
                    Text(block.name)
                        .font(Theme.Font.cardTitle)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    // Date range
                    HStack(spacing: Theme.Space.xs) {
                        Text(block.startDate.formatted(.dateTime.month(.abbreviated).day().year()))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(block.completedDate?.formatted(.dateTime.month(.abbreviated).day().year()) ?? "")
                    }
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(.secondary)

                    // Duration and workout count
                    HStack(spacing: Theme.Space.sm) {
                        Text(durationText(for: block))
                            .font(Theme.Font.cardCaption)
                            .foregroundColor(.secondary)

                        Text("\u{00B7}")
                            .foregroundColor(.secondary)

                        Text("\(blocksVM.workoutCounts[block.id] ?? 0) workouts")
                            .font(Theme.Font.cardCaption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
        }
        .contextMenu {
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
            .tint(.red)
        }
    }

    // MARK: - Duration Helper

    private func durationText(for block: Block) -> String {
        guard let completedDate = block.completedDate else { return "" }
        let weeks = Calendar.current.dateComponents(
            [.weekOfYear],
            from: block.startDate,
            to: completedDate
        ).weekOfYear ?? 0
        let actualWeeks = max(1, weeks)
        return "\(actualWeeks) week\(actualWeeks == 1 ? "" : "s")"
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Space.md) {
            Image(systemName: "checkmark.rectangle.stack")
                .font(.system(size: Theme.IconSize.xl))
                .foregroundColor(.secondary)

            Text("No completed blocks")
                .font(Theme.Font.cardTitle)

            Text("Blocks will appear here once you mark them as complete.")
                .font(Theme.Font.cardSecondary)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
