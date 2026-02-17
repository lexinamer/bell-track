import SwiftUI

struct BlockSelectorView: View {
    let activeBlocks: [Block]
    let pastBlocks: [Block]
    let selectedBlockId: String?
    let completedBlocksOnly: Bool
    let onSelect: (Block) -> Void
    let onEdit: (Block) -> Void
    let onComplete: ((Block) -> Void)?
    let onDelete: (Block) -> Void
    let onDismiss: () -> Void

    init(
        activeBlocks: [Block],
        pastBlocks: [Block],
        selectedBlockId: String?,
        completedBlocksOnly: Bool = false,
        onSelect: @escaping (Block) -> Void,
        onEdit: @escaping (Block) -> Void,
        onComplete: ((Block) -> Void)? = nil,
        onDelete: @escaping (Block) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.activeBlocks = activeBlocks
        self.pastBlocks = pastBlocks
        self.selectedBlockId = selectedBlockId
        self.completedBlocksOnly = completedBlocksOnly
        self.onSelect = onSelect
        self.onEdit = onEdit
        self.onComplete = onComplete
        self.onDelete = onDelete
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if !completedBlocksOnly {
                    ForEach(activeBlocks) { block in
                        blockOption(
                            block: block,
                            isSelected: selectedBlockId == block.id,
                            isCurrent: true
                        )
                        Divider()
                    }
                }

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(pastBlocks) { block in
                            blockOption(
                                block: block,
                                isSelected: selectedBlockId == block.id,
                                isCurrent: false
                            )
                            Divider()
                        }
                    }
                }
            }
            .background(Color.brand.background)
            .navigationTitle(completedBlocksOnly ? "Completed Blocks" : "Select Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .foregroundColor(Color.brand.textPrimary)
                }
            }
        }
    }

    private func blockOption(block: Block, isSelected: Bool, isCurrent: Bool) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"

        return HStack(spacing: 0) {
            Button(action: {
                onSelect(block)
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: Theme.Space.sm) {
                            Text(block.name)
                                .font(Theme.Font.cardTitle)
                                .foregroundColor(Color.brand.textPrimary)

                            if isCurrent {
                                Text("ACTIVE")
                                    .font(Theme.Font.statLabel)
                                    .foregroundColor(Color.brand.primary)
                                    .padding(.horizontal, Theme.Space.sm)
                                    .padding(.vertical, 2)
                                    .background(Color.brand.primary.opacity(0.15))
                                    .cornerRadius(Theme.Radius.xs)
                            }
                        }

                        if let completedDate = block.completedDate {
                            Text("Completed \(completedDate.shortDateString)")
                                .font(Theme.Font.cardSecondary)
                                .foregroundColor(Color.brand.textSecondary)
                        } else {
                            let startText = formatter.string(from: block.startDate)
                            Text("Started \(startText)")
                                .font(Theme.Font.cardSecondary)
                                .foregroundColor(Color.brand.textSecondary)
                        }
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if !completedBlocksOnly {
                Menu {
                    Button {
                        onEdit(block)
                    } label: {
                        Label("Edit Block", systemImage: "pencil")
                    }

                    if block.completedDate == nil, let onComplete = onComplete {
                        Button {
                            onComplete(block)
                        } label: {
                            Label("Complete Block", systemImage: "checkmark.circle")
                        }
                    }

                    Button(role: .destructive) {
                        onDelete(block)
                    } label: {
                        Label("Delete Block", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(Color.brand.textSecondary)
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.vertical, Theme.Space.sm)
        .background(Color.brand.background)
    }
}
