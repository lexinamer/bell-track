import SwiftUI

struct CompletedBlocksView: View {

    @ObservedObject var blocksVM: BlocksViewModel

    // MARK: - Navigation State

    @State private var selectedBlock: Block?

    // MARK: - Edit/Delete State

    @State private var editingBlock: Block?
    @State private var blockToDelete: Block?

    // MARK: - Derived

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

            if completedBlocks.isEmpty {

                emptyState

            } else {

                ScrollView {

                    LazyVStack(
                        spacing: Theme.Space.md
                    ) {

                        ForEach(completedBlocks) { block in

                            completedBlockCard(block)
                                .onTapGesture {
                                    selectedBlock = block
                                }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, Theme.Space.sm)
                }
            }
        }
        .navigationTitle("Completed Blocks")
        .navigationBarTitleDisplayMode(.large)

        // MARK: - Navigation

        .navigationDestination(item: $selectedBlock) { block in
            BlockDetailView(block: block)
        }

        // MARK: - Edit Sheet

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
                onCancel: {
                    editingBlock = nil
                }
            )
        }

        // MARK: - Delete Alert

        .alert(
            "Delete Block?",
            isPresented: deleteBinding
        ) {

            Button("Cancel", role: .cancel) { }

            Button("Delete", role: .destructive) {

                if let block = blockToDelete {

                    Task {
                        await blocksVM.deleteBlock(id: block.id)
                    }
                }
            }

        } message: {

            Text(
                "This will permanently delete \"\(blockToDelete?.name ?? "")\". Workouts assigned to this block will not be deleted."
            )
        }
    }

    // MARK: - Completed Block Card

    private func completedBlockCard(
        _ block: Block
    ) -> some View {

        SimpleCard {

            HStack(
                spacing: Theme.Space.smp
            ) {

                colorIndicator(block)

                VStack(
                    alignment: .leading,
                    spacing: Theme.Space.xs
                ) {

                    Text(block.name)
                        .font(Theme.Font.cardTitle)
                        .fontWeight(.semibold)

                    dateRangeRow(block)

                    durationRow(block)
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
        }
    }

    // MARK: - Color Indicator

    private func colorIndicator(
        _ block: Block
    ) -> some View {

        RoundedRectangle(
            cornerRadius: 2
        )
        .fill(
            ColorTheme.blockColor(
                for: block.colorIndex
            )
        )
        .frame(width: 4)
    }

    // MARK: - Date Range

    private func dateRangeRow(
        _ block: Block
    ) -> some View {

        HStack(
            spacing: Theme.Space.xs
        ) {

            Text(
                block.startDate.formatted(
                    .dateTime
                        .month(.abbreviated)
                        .day()
                        .year()
                )
            )

            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Text(
                block.completedDate?.formatted(
                    .dateTime
                        .month(.abbreviated)
                        .day()
                        .year()
                ) ?? ""
            )
        }
        .font(Theme.Font.cardCaption)
        .foregroundColor(.secondary)
    }

    // MARK: - Duration Row

    private func durationRow(
        _ block: Block
    ) -> some View {

        HStack(
            spacing: Theme.Space.sm
        ) {

            Text(durationText(for: block))

            Text("·")

            Text(
                "\(blocksVM.workoutCounts[block.id] ?? 0) workouts"
            )
        }
        .font(Theme.Font.cardCaption)
        .foregroundColor(.secondary)
    }

    // MARK: - Duration Logic

    private func durationText(
        for block: Block
    ) -> String {

        guard let completedDate = block.completedDate else {
            return ""
        }

        let weeks =
            Calendar.current.dateComponents(
                [.weekOfYear],
                from: block.startDate,
                to: completedDate
            ).weekOfYear ?? 0

        let actualWeeks = max(1, weeks)

        return "\(actualWeeks) week\(actualWeeks == 1 ? "" : "s")"
    }

    // MARK: - Empty State

    private var emptyState: some View {

        VStack(
            spacing: Theme.Space.md
        ) {

            Image(systemName: "checkmark.rectangle.stack")
                .font(
                    .system(
                        size: Theme.IconSize.xl
                    )
                )
                .foregroundColor(.secondary)

            Text("No completed blocks")
                .font(Theme.Font.emptyStateTitle)

            Text(
                "Blocks will appear here once you mark them as complete."
            )
            .font(Theme.Font.emptyStateDescription)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.xl)
    }

    // MARK: - Bindings

    private var deleteBinding: Binding<Bool> {

        Binding(
            get: {
                blockToDelete != nil
            },
            set: {
                if !$0 {
                    blockToDelete = nil
                }
            }
        )
    }
}
