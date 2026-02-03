import SwiftUI

struct BlocksView: View {

    @StateObject private var vm = BlocksViewModel()

    @State private var showingForm = false
    @State private var editingBlock: Block?
    @State private var showingDetail = false
    @State private var selectedBlock: Block?

    // Form state
    @State private var name = ""
    @State private var startDate = Date()
    @State private var type: BlockType = .ongoing
    @State private var durationWeeks: Int?

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
            blockForm
        }
        .sheet(isPresented: $showingDetail) {
            BlockDetailView(block: selectedBlock ?? Block(id: "", name: "Error", startDate: Date(), type: .ongoing, durationWeeks: nil))
        }
        .task {
            await vm.load()
        }
    }

    // MARK: - Block Card

    private func blockCard(_ block: Block) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Block details
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
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .contentShape(Rectangle())
        .onTapGesture {
            print("🔍 Tapping block: \(block.name)")
            selectedBlock = block
            showingDetail = true
            print("🔍 Set showingDetail to true, selectedBlock: \(selectedBlock?.name ?? "nil")")
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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.split.1x2")
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
