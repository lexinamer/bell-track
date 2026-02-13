import SwiftUI

struct BlockFormView: View {
    let block: Block?
    let blocksVM: BlocksViewModel?
    let onSave: (String, Date, BlockType, Int?, String?, Int?) -> Void
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

    private let firestore = FirestoreService()

    init(
        block: Block? = nil,
        blocksVM: BlocksViewModel? = nil,
        onSave: @escaping (String, Date, BlockType, Int?, String?, Int?) -> Void,
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

                // Templates section (only when editing an existing block)
                if block != nil {
                    Section {
                        if blockTemplates.isEmpty {
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
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(template.name)
                                            .font(Theme.Font.cardTitle)
                                            .foregroundColor(.primary)
                                        Text(template.entries.map { $0.exerciseName }.joined(separator: ", "))
                                            .font(Theme.Font.cardCaption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
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

                        NavigationLink {
                            WorkoutTemplateFormView(
                                exercises: exercises,
                                complexes: complexes,
                                onSave: { templateName, entries in
                                    if let blockId = block?.id {
                                        Task {
                                            await blocksVM?.saveTemplate(
                                                id: nil,
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
                        onSave(name, startDate, blockType, durationWeeks, finalNotes.isEmpty ? nil : finalNotes, colorIndex)
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
            .task {
                if block != nil {
                    exercises = (try? await firestore.fetchExercises()) ?? []
                    complexes = (try? await firestore.fetchComplexes()) ?? []
                }
            }
        }
    }
}
