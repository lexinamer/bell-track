import SwiftUI

struct BlockFormView: View {
    let block: Block?
    let blocksVM: BlocksViewModel?
    let onSave: (String, Date, BlockType, Int?, String?, Int?, [(name: String, entries: [TemplateEntry])]) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var startDate: Date
    @State private var isDuration: Bool
    @State private var durationWeeks: Int?
    @State private var notes: String
    @State private var colorIndex: Int

    // Template management state
    @State private var exercises: [Exercise] = []
    @State private var complexes: [Complex] = []
    @State private var templateToDelete: WorkoutTemplate? = nil

    // Pending templates for new blocks (not yet saved to Firestore)
    @State private var pendingTemplates: [(name: String, entries: [TemplateEntry])] = []
    @State private var pendingIndexToDelete: Int? = nil

    private let firestore = FirestoreService()

    init(
        block: Block? = nil,
        blocksVM: BlocksViewModel? = nil,
        onSave: @escaping (String, Date, BlockType, Int?, String?, Int?, [(name: String, entries: [TemplateEntry])]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.block = block
        self.blocksVM = blocksVM
        self.onSave = onSave
        self.onCancel = onCancel

        self._name = State(initialValue: block?.name ?? "")
        self._startDate = State(initialValue: block?.startDate ?? Date())
        self._isDuration = State(initialValue: block?.type == .duration)
        self._durationWeeks = State(initialValue: block?.durationWeeks)
        self._notes = State(initialValue: block?.notes ?? "")
        self._colorIndex = State(initialValue: block?.colorIndex ?? 0)
    }

    private var blockTemplates: [WorkoutTemplate] {
        guard let blockId = block?.id, let vm = blocksVM else { return [] }
        return vm.templatesForBlock(blockId)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Block name", text: $name)
                        .autocorrectionDisabled()

                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)

                    Toggle("Duration block", isOn: $isDuration)

                    if isDuration {
                        HStack {
                            Text("Duration")
                            Spacer()
                            TextField("Weeks", value: $durationWeeks, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }
                }

                Section("Goal") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }

                Section("Color") {
                    HStack(spacing: Theme.Space.md) {
                        ForEach(0..<ColorTheme.blockPalette.count, id: \.self) { idx in
                            Circle()
                                .fill(ColorTheme.blockPalette[idx])
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.primary, lineWidth: colorIndex == idx ? 2.5 : 0)
                                )
                                .onTapGesture {
                                    colorIndex = idx
                                }
                        }
                        Spacer()
                    }
                }

                // Templates section — available for both new and existing blocks
                Section {
                    // Existing saved templates (editing an existing block)
                    if block != nil {
                        if blockTemplates.isEmpty && pendingTemplates.isEmpty {
                            Text("No templates yet")
                                .font(Theme.Font.cardSecondary)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(blockTemplates) { template in
                                NavigationLink {
                                    WorkoutTemplateFormView(
                                        template: template,
                                        exercises: exercises,
                                        complexes: complexes,
                                        onSave: { templateName, entries in
                                            if let blockId = block?.id {
                                                Task {
                                                    await blocksVM?.saveTemplate(
                                                        id: template.id,
                                                        name: templateName,
                                                        blockId: blockId,
                                                        entries: entries
                                                    )
                                                }
                                            }
                                        },
                                        onCancel: {}
                                    )
                                } label: {
                                    templateRow(name: template.name, entries: template.entries)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        templateToDelete = template
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }

                    // Pending templates (for new blocks, or additional ones while editing)
                    if block == nil && pendingTemplates.isEmpty {
                        Text("No templates yet")
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(.secondary)
                    }

                    ForEach(Array(pendingTemplates.enumerated()), id: \.offset) { index, pending in
                        NavigationLink {
                            WorkoutTemplateFormView(
                                template: WorkoutTemplate(
                                    id: "pending-\(index)",
                                    name: pending.name,
                                    blockId: "",
                                    entries: pending.entries
                                ),
                                exercises: exercises,
                                complexes: complexes,
                                onSave: { templateName, entries in
                                    pendingTemplates[index] = (name: templateName, entries: entries)
                                },
                                onCancel: {}
                            )
                        } label: {
                            templateRow(name: pending.name, entries: pending.entries)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                pendingIndexToDelete = index
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    NavigationLink {
                        WorkoutTemplateFormView(
                            exercises: exercises,
                            complexes: complexes,
                            onSave: { templateName, entries in
                                if let blockId = block?.id {
                                    // Editing existing block — save directly
                                    Task {
                                        await blocksVM?.saveTemplate(
                                            id: nil,
                                            name: templateName,
                                            blockId: blockId,
                                            entries: entries
                                        )
                                    }
                                } else {
                                    // New block — store locally until block is saved
                                    pendingTemplates.append((name: templateName, entries: entries))
                                }
                            },
                            onCancel: {}
                        )
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Template")
                        }
                        .foregroundColor(Color.brand.primary)
                    }
                } header: {
                    Text("Workout Templates")
                }
            }
            .navigationTitle(block == nil ? "New Block" : "Edit Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let blockType: BlockType = isDuration ? .duration : .ongoing
                        let finalNotes = notes.trimmingCharacters(in: .whitespaces)
                        onSave(name, startDate, blockType, durationWeeks, finalNotes.isEmpty ? nil : finalNotes, colorIndex, pendingTemplates)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty ||
                             (isDuration && (durationWeeks == nil || durationWeeks! <= 0)))
                }
            }
            .alert("Delete Template?", isPresented: .init(
                get: { templateToDelete != nil },
                set: { if !$0 { templateToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) { templateToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let template = templateToDelete {
                        Task { await blocksVM?.deleteTemplate(id: template.id) }
                    }
                    templateToDelete = nil
                }
            } message: {
                Text("This will permanently delete \"\(templateToDelete?.name ?? "")\".")
            }
            .alert("Delete Template?", isPresented: .init(
                get: { pendingIndexToDelete != nil },
                set: { if !$0 { pendingIndexToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) { pendingIndexToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let index = pendingIndexToDelete, pendingTemplates.indices.contains(index) {
                        pendingTemplates.remove(at: index)
                    }
                    pendingIndexToDelete = nil
                }
            } message: {
                if let index = pendingIndexToDelete, pendingTemplates.indices.contains(index) {
                    Text("This will remove \"\(pendingTemplates[index].name)\".")
                }
            }
            .task {
                exercises = (try? await firestore.fetchExercises()) ?? []
                complexes = (try? await firestore.fetchComplexes()) ?? []
            }
        }
    }

    // MARK: - Template Row

    private func templateRow(name: String, entries: [TemplateEntry]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(Theme.Font.cardTitle)
                .foregroundColor(.primary)
            Text(entries.map { $0.exerciseName }.joined(separator: ", "))
                .font(Theme.Font.cardCaption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}
