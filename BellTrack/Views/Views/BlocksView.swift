import SwiftUI

struct BlocksView: View {

    @StateObject private var vm = BlocksViewModel()

    @State private var showingForm = false
    @State private var editingBlock: Block?
    @State private var showingDetail = false
    @State private var selectedBlock: Block?

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Shared header component
                PageHeader(
                    title: "Blocks",
                    buttonText: "Add Block"
                ) {
                    startCreate()
                }
                
                // Content
                if vm.blocks.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    List {
                        ForEach(vm.blocks) { block in
                            blockCard(block)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("Delete", role: .destructive) {
                                        Task {
                                            await vm.deleteBlock(id: block.id)
                                        }
                                    }
                                    .tint(.red)
                                    
                                    Button("Edit") {
                                        startEdit(block)
                                    }
                                    .tint(.orange)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 6)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingForm) {
            BlockFormView(
                block: editingBlock,
                onSave: { name, startDate, type, durationWeeks in
                    Task {
                        await vm.saveBlock(
                            id: editingBlock?.id,
                            name: name,
                            startDate: startDate,
                            type: type,
                            durationWeeks: durationWeeks
                        )
                        resetForm()
                    }
                },
                onCancel: {
                    resetForm()
                }
            )
        }
        .sheet(isPresented: $showingDetail) {
            if let block = selectedBlock {
                DetailView(block: block)
            }
        }
        .task {
            await vm.load()
        }
    }

    // MARK: - Block Card

    private func blockCard(_ block: Block) -> some View {
        SimpleCard(onTap: {
            selectedBlock = block
            showingDetail = true
        }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(block.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(progressText(block))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "dumbbell")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    let count = vm.workoutCounts[block.id] ?? 0
                    Text("\(count) workouts")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Progress Text

    private func progressText(_ block: Block) -> String {
        switch block.type {
        case .ongoing:
            let weeksSinceStart = Calendar.current.dateComponents([.weekOfYear], from: block.startDate, to: Date()).weekOfYear ?? 0
            return "Week \(max(1, weeksSinceStart + 1)) - Ongoing"
        case .duration:
            if let weeks = block.durationWeeks {
                let weeksSinceStart = Calendar.current.dateComponents([.weekOfYear], from: block.startDate, to: Date()).weekOfYear ?? 0
                let currentWeek = min(max(1, weeksSinceStart + 1), weeks)
                return "Week \(currentWeek) of \(weeks)"
            } else {
                return "Duration"
            }
        }
    }

    // MARK: - Helpers

    private func startCreate() {
        editingBlock = nil
        showingForm = true
    }

    private func startEdit(_ block: Block) {
        editingBlock = block
        showingForm = true
    }

    private func resetForm() {
        showingForm = false
        editingBlock = nil
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "cube")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No blocks yet")
                .font(.headline)

            Text("Create a block to organize workouts.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}
