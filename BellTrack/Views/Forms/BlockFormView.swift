import SwiftUI

struct BlockFormView: View {
    let block: Block?
    let onSave: (String, String, Date, Date?) -> Void
    let onDelete: (() -> Void)?
    let onComplete: (() -> Void)?
    let onCancel: () -> Void

    @State private var name: String
    @State private var goal: String
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var showingDeleteAlert = false
    @State private var showingCompleteAlert = false

    init(
        block: Block? = nil,
        onSave: @escaping (String, String, Date, Date?) -> Void,
        onDelete: (() -> Void)? = nil,
        onComplete: (() -> Void)? = nil,
        onCancel: @escaping () -> Void
    ) {
        self.block = block
        self.onSave = onSave
        self.onDelete = onDelete
        self.onComplete = onComplete
        self.onCancel = onCancel
        _name = State(initialValue: block?.name ?? "")
        _goal = State(initialValue: block?.goal ?? "")
        _startDate = State(initialValue: block?.startDate ?? Date())
        _hasEndDate = State(initialValue: block?.endDate != nil)
        _endDate = State(initialValue: block?.endDate ?? Calendar.current.date(byAdding: .weekOfYear, value: 4, to: Date())!)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Block name", text: $name)
                        .autocorrectionDisabled()

                    TextField("Goal (optional)", text: $goal)
                        .foregroundColor(Color.brand.textPrimary)
                }

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

                // Destructive actions — only shown when editing an existing block
                if block != nil {
                    Section {
                        if onComplete != nil {
                            Button {
                                showingCompleteAlert = true
                            } label: {
                                Label("Mark as Complete", systemImage: "checkmark.circle")
                                    .foregroundColor(Color.brand.textPrimary)
                            }
                        }

                        if onDelete != nil {
                            Button(role: .destructive) {
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete Block", systemImage: "trash")
                            }
                        }
                    }
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
                        onSave(name, goal, startDate, hasEndDate ? endDate : nil)
                    }
                    .disabled(!canSave)
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
