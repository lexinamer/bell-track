import SwiftUI

struct BlocksView: View {

    @StateObject private var vm = BlocksViewModel()

    @State private var showingForm = false
    @State private var editingBlock: Block?
    @State private var selectedBlock: Block?
    @State private var showingCompletionAlert = false
    @State private var blockToComplete: Block?

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
                        // Active blocks section
                        let activeBlocks = vm.blocks.filter { $0.completedDate == nil }
                        if !activeBlocks.isEmpty {
                            ForEach(activeBlocks) { block in
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
                        
                        // Completed blocks section
                        let completedBlocks = vm.blocks.filter { $0.completedDate != nil }
                        if !completedBlocks.isEmpty {
                            Section("Completed") {
                                ForEach(completedBlocks) { block in
                                    completedBlockCard(block)
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
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 6)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(item: $editingBlock) { block in
            BlockFormView(
                block: block,  // Now guaranteed to not be nil
                onSave: { name, startDate, type, durationWeeks, notes in
                    Task {
                        await vm.saveBlock(
                            id: block.id,  // Use the guaranteed non-nil block
                            name: name,
                            startDate: startDate,
                            type: type,
                            durationWeeks: durationWeeks,
                            notes: notes
                        )
                        resetForm()
                    }
                },
                onCancel: {
                    resetForm()
                }
            )
        }
        .sheet(item: $selectedBlock) { block in
            DetailView(block: block)
        }
        .task {
            await vm.load()
        }
        .alert("Complete Block?", isPresented: $showingCompletionAlert) {
            Button("Cancel", role: .cancel) {
                blockToComplete = nil
            }
            Button("Complete") {
                if let block = blockToComplete {
                    Task {
                        await vm.completeBlock(id: block.id)
                        blockToComplete = nil
                    }
                }
            }
        } message: {
            if let block = blockToComplete {
                Text("Mark \"\(block.name)\" as completed?")
            }
        }
    }

    // MARK: - Block Card

    private func blockCard(_ block: Block) -> some View {
        SimpleCard(onTap: {
            selectedBlock = block
        }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(block.name)
                    .font(Theme.Font.cardTitle)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack {
                    Image(systemName: "calendar")
                        .font(Theme.Font.cardCaption)
                        .foregroundColor(.secondary)
                    
                    Text(progressText(block))
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "dumbbell")
                        .font(Theme.Font.cardCaption)
                        .foregroundColor(.secondary)
                    
                    let count = vm.workoutCounts[block.id] ?? 0
                    Text("\(count) workouts")
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onLongPressGesture {
            blockToComplete = block
            showingCompletionAlert = true
        }
    }
    
    // MARK: - Completed Block Card
    
    private func completedBlockCard(_ block: Block) -> some View {
        SimpleCard(onTap: {
            selectedBlock = block
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(block.name)
                        .font(Theme.Font.cardTitle)
                        .foregroundColor(.secondary)  // Grayed out text
                        .lineLimit(2)
                    
                    HStack {
                        Image(systemName: "calendar")
                            .font(Theme.Font.cardCaption)
                            .foregroundColor(.secondary)
                        
                        if let completedDate = block.completedDate {
                            Text("Completed \(completedDate.formatted(.dateTime.month(.abbreviated).day()))")
                                .font(Theme.Font.cardSecondary)
                                .foregroundColor(.secondary)
                        }
                        
                        Image(systemName: "dumbbell")
                            .font(Theme.Font.cardCaption)
                            .foregroundColor(.secondary)
                        
                        let count = vm.workoutCounts[block.id] ?? 0
                        Text("\(count) workouts")
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Checkmark indicator
                Image(systemName: "checkmark.circle.fill")
                    .font(Theme.Font.navigationTitle)
                    .foregroundColor(.green)
            }
        }
    }

    // MARK: - Progress Text

    private func progressText(_ block: Block) -> String {
        switch block.type {
        case .ongoing:
            let weeksSinceStart = Calendar.current.dateComponents([.weekOfYear], from: block.startDate, to: Date()).weekOfYear ?? 0
            return "Week \(max(1, weeksSinceStart + 1)) (ongoing)"
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
            Image(systemName: "cube.fill")
                .font(.system(size: Theme.IconSize.xl))
                .foregroundColor(.secondary)

            Text("No blocks yet")
                .font(Theme.Font.cardTitle)

            Text("Create a block to organize workouts.")
                .font(Theme.Font.cardSecondary)
                .foregroundColor(.secondary)
        }
    }
}
