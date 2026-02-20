import SwiftUI

struct WorkoutTemplateFormView: View {

    let template: WorkoutTemplate?
    let exercises: [Exercise]
    let onSave: (String, [TemplateEntry]) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var nameInput: String
    @State private var selectedEntries: [TemplateEntry]

    init(
        template: WorkoutTemplate? = nil,
        exercises: [Exercise],
        onSave: @escaping (String, [TemplateEntry]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.template = template
        self.exercises = exercises
        self.onSave = onSave
        self.onCancel = onCancel
        _nameInput = State(initialValue: template?.name ?? "")
        _selectedEntries = State(initialValue: template?.entries ?? [])
    }

    private var canSave: Bool {
        !nameInput.trimmingCharacters(in: .whitespaces).isEmpty && !selectedEntries.isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField("Template name (e.g. Workout A)", text: $nameInput)
                    .autocorrectionDisabled()
            }

            // Workout exercises (selected, ordered)
            Section {
                if selectedEntries.isEmpty {
                    Text("Tap an exercise below to add it")
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(selectedEntries) { entry in
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                            Text(entry.exerciseName)
                        }
                    }
                    .onDelete { offsets in
                        selectedEntries.remove(atOffsets: offsets)
                    }
                    .onMove { from, to in
                        selectedEntries.move(fromOffsets: from, toOffset: to)
                    }
                }
            } header: {
                Text("Workout Exercises (\(selectedEntries.count))")
            }

            // Available exercises to tap-add
            Section("Add Exercise") {
                if exercises.isEmpty {
                    Text("No exercises available. Create exercises first.")
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(exercises) { exercise in
                        let isAdded = selectedEntries.contains { $0.exerciseId == exercise.id }
                        Button {
                            addEntry(exerciseId: exercise.id, name: exercise.name)
                        } label: {
                            HStack {
                                Text(exercise.name)
                                    .foregroundColor(isAdded ? Color.brand.primary : .primary)
                                Spacer()
                                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                                    .foregroundColor(isAdded ? Color.brand.primary : Color.brand.primary)
                            }
                        }
                        .disabled(isAdded)
                    }
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle(template == nil ? "New Template" : "Edit Template")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onCancel()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(nameInput, selectedEntries)
                    dismiss()
                }
                .disabled(!canSave)
            }
        }
    }

    private func addEntry(exerciseId: String, name: String) {
        selectedEntries.append(
            TemplateEntry(
                exerciseId: exerciseId,
                exerciseName: name
            )
        )
    }
}
