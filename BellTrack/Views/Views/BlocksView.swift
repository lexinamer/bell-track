import SwiftUI

struct BlocksView: View {

    @StateObject private var vm = BlocksViewModel()

    @State private var showingForm = false
    @State private var editingBlock: Block?

    // Form state
    @State private var name = ""
    @State private var startDate = Date()
    @State private var type: BlockType = .ongoing
    @State private var durationWeeks: Int?

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            if vm.blocks.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(vm.blocks) { block in
                        blockRow(block)
                    }
                    .onDelete { indexSet in
                        Task {
                            for index in indexSet {
                                await vm.deleteBlock(id: vm.blocks[index].id)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Blocks")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    startCreate()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            blockForm
        }
        .task {
            await vm.load()
        }
    }

    // MARK: - Row

    private func blockRow(_ block: Block) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {

            Text(block.name)
                .font(Theme.Font.headline)

            Text(progressText(block))
                .font(Theme.Font.body)
                .foregroundColor(Color.brand.textSecondary)

            let count = vm.workoutCounts[block.id] ?? 0
            Text("\(count) workouts")
                .font(Theme.Font.meta)
                .foregroundColor(Color.brand.textSecondary)
        }
        .padding(.vertical, Theme.Space.sm)
        .onTapGesture {
            startEdit(block)
        }
    }

    // MARK: - Progress

    private func progressText(_ block: Block) -> String {
        switch block.type {
        case .ongoing:
            return "Ongoing"
        case .duration:
            if let weeks = block.durationWeeks {
                return "Week 1 of \(weeks)"
            } else {
                return "Duration"
            }
        }
    }

    // MARK: - Form

    private var blockForm: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Block name", text: $name)

                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)

                    Picker("Type", selection: $type) {
                        Text("Ongoing").tag(BlockType.ongoing)
                        Text("Duration").tag(BlockType.duration)
                    }

                    if type == .duration {
                        TextField(
                            "Duration (weeks)",
                            value: $durationWeeks,
                            format: .number
                        )
                        .keyboardType(.numberPad)
                    }
                }
            }
            .navigationTitle(editingBlock == nil ? "New Block" : "Edit Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        resetForm()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
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
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Helpers

    private func startCreate() {
        editingBlock = nil
        name = ""
        startDate = Date()
        type = .ongoing
        durationWeeks = nil
        showingForm = true
    }

    private func startEdit(_ block: Block) {
        editingBlock = block
        name = block.name
        startDate = block.startDate
        type = block.type
        durationWeeks = block.durationWeeks
        showingForm = true
    }

    private func resetForm() {
        showingForm = false
        editingBlock = nil
        name = ""
        durationWeeks = nil
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: Theme.Space.md) {
            Image(systemName: "square.split.1x2")
                .font(.system(size: 40))
                .foregroundColor(Color.brand.textSecondary)

            Text("No blocks yet")
                .font(Theme.Font.headline)

            Text("Create a block to organize workouts.")
                .font(Theme.Font.body)
                .foregroundColor(Color.brand.textSecondary)
        }
    }
}
