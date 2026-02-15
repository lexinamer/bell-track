import SwiftUI

struct BlockFormView: View {
    let block: Block?
    let blocksVM: BlocksViewModel?
    let onSave: (String, Date, Date?, String?, Int?, [(name: String, entries: [TemplateEntry])]) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
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
        onSave: @escaping (String, Date, Date?, String?, Int?, [(name: String, entries: [TemplateEntry])]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.block = block
        self.blocksVM = blocksVM
        self.onSave = onSave
        self.onCancel = onCancel

        self._name = State(initialValue: block?.name ?? "")
        self._startDate = State(initialValue: block?.startDate ?? Date())
        self._hasEndDate = State(initialValue: block?.endDate != nil)
        self._endDate = State(initialValue: block?.endDate ?? Calendar.current.date(byAdding: .weekOfYear, value: 4, to: Date())!)
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

                    HStack {
                        Text("Start date")
                        Spacer()
                        DatePicker(
                            "",
                            selection: $startDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                    }

                    Toggle("End date", isOn: $hasEndDate)
                        .onChange(of: hasEndDate) { _, enabled in
                            if enabled {
                                endDate = Calendar.current.date(
                                    byAdding: .weekOfYear,
                                    value: 4,
                                    to: startDate
                                )!
                            }
                        }
                    
                    if hasEndDate {
                        HStack(spacing: Theme.Space.sm) {
                            durationChip(weeks: 4)
                            durationChip(weeks: 6)
                            durationChip(weeks: 8)
                            durationChip(weeks: 10)
                            Spacer()
                        }
                        HStack {
                            Text("End date")
                            Spacer()
                            DatePicker(
                                "",
                                selection: $endDate,
                                in: startDate.addingTimeInterval(86400)...,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
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
                                    Task {
                                        await blocksVM?.saveTemplate(
                                            id: nil,
                                            name: templateName,
                                            blockId: blockId,
                                            entries: entries
                                        )
                                    }
                                } else {
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
                        let finalNotes = notes.trimmingCharacters(in: .whitespaces)
                        let finalEndDate: Date? = hasEndDate ? endDate : nil
                        onSave(name, startDate, finalEndDate, finalNotes.isEmpty ? nil : finalNotes, colorIndex, pendingTemplates)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
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

    // MARK: - Duration Chip

    private func durationChip(weeks: Int) -> some View {
        let target = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: startDate)!
        let isSelected = Calendar.current.isDate(endDate, inSameDayAs: target)

        return Button("\(weeks) wks") {
            endDate = target
        }
        .buttonStyle(.borderless)
        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.brand.primary : Color(.tertiarySystemFill))
        .foregroundColor(isSelected ? .white : .primary)
        .clipShape(Capsule())
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
