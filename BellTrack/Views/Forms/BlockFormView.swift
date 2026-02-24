import SwiftUI

struct BlockFormView: View {
    let block: Block?
    let existingTemplates: [WorkoutTemplate]
    let exercises: [Exercise]
    let onSave: (String, String, Date, Date?, [WorkoutTemplate]) -> Void
    let onDelete: (() -> Void)?
    let onComplete: (() -> Void)?
    let onCancel: () -> Void

    @State private var name: String
    @State private var goal: String
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var pendingTemplates: [WorkoutTemplate]
    @State private var showingDeleteAlert = false
    @State private var showingCompleteAlert = false
    @State private var addingTemplate = false
    @State private var editingTemplate: WorkoutTemplate?
    @State private var didAttemptSave = false

    private let blockId: String

    init(
        block: Block? = nil,
        existingTemplates: [WorkoutTemplate] = [],
        exercises: [Exercise] = [],
        onSave: @escaping (String, String, Date, Date?, [WorkoutTemplate]) -> Void,
        onDelete: (() -> Void)? = nil,
        onComplete: (() -> Void)? = nil,
        onCancel: @escaping () -> Void
    ) {
        self.block = block
        self.existingTemplates = existingTemplates
        self.exercises = exercises
        self.onSave = onSave
        self.onDelete = onDelete
        self.onComplete = onComplete
        self.onCancel = onCancel
        self.blockId = block?.id ?? UUID().uuidString
        _name = State(initialValue: block?.name ?? "")
        _goal = State(initialValue: block?.goal ?? "")
        _startDate = State(initialValue: block?.startDate ?? Date())
        _hasEndDate = State(initialValue: block?.endDate != nil)
        _endDate = State(initialValue: block?.endDate ?? Calendar.current.date(byAdding: .weekOfYear, value: 4, to: Date())!)
        _pendingTemplates = State(initialValue: existingTemplates)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !pendingTemplates.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                infoSection
                datesSection
                templatesSection
                if block != nil {
                    destructiveSection
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.brand.background)
            .navigationTitle(block == nil ? "New Block" : "Edit Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        didAttemptSave = true
                        guard canSave else { return }
                        onSave(name, goal, startDate, hasEndDate ? endDate : nil, pendingTemplates)
                    }
                }
            }
            .alert("Mark as Complete?", isPresented: $showingCompleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Complete") { onComplete?() }
            } message: {
                Text("This will mark the block as finished. You can still view past workouts.")
            }
            .alert("Delete Block?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { onDelete?() }
            } message: {
                Text("This will permanently delete \"\(block?.name ?? "")\" and all its workouts.")
            }
            .fullScreenCover(isPresented: $addingTemplate) {
                WorkoutTemplateFormView(
                    exercises: exercises,
                    onSave: { templateName, entries, workoutType, duration in
                        let newTemplate = WorkoutTemplate(
                            id: UUID().uuidString,
                            name: templateName,
                            blockId: blockId,
                            entries: entries,
                            workoutType: workoutType,
                            duration: duration
                        )
                        pendingTemplates.append(newTemplate)
                        addingTemplate = false
                    },
                    onCancel: { addingTemplate = false }
                )
            }
            .fullScreenCover(item: $editingTemplate) { template in
                WorkoutTemplateFormView(
                    template: template,
                    exercises: exercises,
                    onSave: { templateName, entries, workoutType, duration in
                        if let index = pendingTemplates.firstIndex(where: { $0.id == template.id }) {
                            pendingTemplates[index] = WorkoutTemplate(
                                id: template.id,
                                name: templateName,
                                blockId: blockId,
                                entries: entries,
                                workoutType: workoutType,
                                duration: duration
                            )
                        }
                        editingTemplate = nil
                    },
                    onDelete: {
                        pendingTemplates.removeAll { $0.id == template.id }
                        editingTemplate = nil
                    },
                    onCancel: { editingTemplate = nil }
                )
            }
        }
    }

    // MARK: - Sections

    private var infoSection: some View {
        Section {
            TextField("Block name", text: $name)
                .autocorrectionDisabled()
            TextField("Goal (optional)", text: $goal)
                .foregroundColor(Color.brand.textPrimary)
        }
    }

    private var datesSection: some View {
        Section(header: Text("Or plan ahead with a future start date").font(Theme.Font.cardCaption)) {
            HStack {
                Text("Start date")
                Spacer()
                DatePicker("", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }

            Toggle("End date", isOn: $hasEndDate)
                .onChange(of: hasEndDate) { _, enabled in
                    if enabled {
                        endDate = Calendar.current.date(byAdding: .weekOfYear, value: 4, to: startDate)!
                    }
                }

            if hasEndDate {
                HStack(spacing: Theme.Space.sm) {
                    durationChip(weeks: 1)
                    durationChip(weeks: 4)
                    durationChip(weeks: 6)
                    durationChip(weeks: 8)
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
    }

    private var templatesSection: some View {
        Section(
            header: Text("Templates"),
            footer: Group {
                if didAttemptSave && pendingTemplates.isEmpty {
                    Text("At least one template is required to save.")
                        .foregroundColor(Color.brand.destructive)
                }
            }
        ) {
            ForEach(pendingTemplates) { template in
                Button {
                    editingTemplate = template
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.name)
                                .foregroundColor(Color.brand.textPrimary)
                            Text(template.workoutType.displayName)
                                .font(Theme.Font.cardCaption)
                                .foregroundColor(Color.brand.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(Color.brand.textSecondary)
                    }
                }
            }
            .onDelete { indexSet in
                pendingTemplates.remove(atOffsets: indexSet)
            }

            Button {
                addingTemplate = true
            } label: {
                Label("Add Template", systemImage: "plus")
                    .foregroundColor(Color.brand.primary)
            }
        }
    }

    @ViewBuilder
    private var destructiveSection: some View {
        Section {
            if onComplete != nil {
                Button {
                    showingCompleteAlert = true
                } label: {
                    Label("Mark as Complete", systemImage: "checkmark.circle")
                }
            }
            if onDelete != nil {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete Block", systemImage: "trash")
                        .foregroundStyle(Color.brand.destructive)
                }
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
        .font(Theme.Font.cardCaption)
        .padding(.horizontal, Theme.Space.smp)
        .padding(.vertical, 6)
        .background(isSelected ? Color.brand.primary : Color.brand.surface)
        .foregroundColor(isSelected ? .white : Color.brand.textPrimary)
        .clipShape(Capsule())
    }
}
