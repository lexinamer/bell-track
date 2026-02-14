import SwiftUI

struct ComplexFormView: View {

    let complex: Complex?
    let exercises: [Exercise]
    let onSave: (String, [String]) -> Void
    let onCancel: () -> Void

    @State private var nameInput: String
    @State private var selectedExerciseIds: Set<String>

    init(
        complex: Complex? = nil,
        exercises: [Exercise],
        onSave: @escaping (String, [String]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.complex = complex
        self.exercises = exercises
        self.onSave = onSave
        self.onCancel = onCancel
        _nameInput = State(initialValue: complex?.name ?? "")
        _selectedExerciseIds = State(initialValue: Set(complex?.exerciseIds ?? []))
    }

    // Derived muscles from selected exercises
    private var derivedPrimary: [MuscleGroup] {
        let components = exercises.filter { selectedExerciseIds.contains($0.id) }
        return Array(Set(components.flatMap { $0.primaryMuscles }))
    }

    private var derivedSecondary: [MuscleGroup] {
        let components = exercises.filter { selectedExerciseIds.contains($0.id) }
        let allSecondary = Set(components.flatMap { $0.secondaryMuscles })
        let primarySet = Set(derivedPrimary)
        return Array(allSecondary.subtracting(primarySet))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Complex name", text: $nameInput)
                        .autocorrectionDisabled()
                }

                Section("Component Exercises") {
                    if exercises.isEmpty {
                        Text("No exercises available. Create exercises first.")
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(exercises) { exercise in
                            Button {
                                toggleExercise(exercise.id)
                            } label: {
                                HStack {
                                    Text(exercise.name)
                                        .foregroundColor(.primary)

                                    Spacer()

                                    if selectedExerciseIds.contains(exercise.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(Color.brand.primary)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        }
                    }
                }

                // Live preview of derived muscles
                if !selectedExerciseIds.isEmpty {
                    Section("Derived Muscles") {
                        MuscleTags(
                            primaryMuscles: derivedPrimary,
                            secondaryMuscles: derivedSecondary
                        )
                    }
                }
            }
            .navigationTitle(complex == nil ? "New Complex" : "Edit Complex")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(nameInput, Array(selectedExerciseIds))
                    }
                    .disabled(
                        nameInput.trimmingCharacters(in: .whitespaces).isEmpty ||
                        selectedExerciseIds.count < 2
                    )
                }
            }
        }
    }

    private func toggleExercise(_ id: String) {
        if selectedExerciseIds.contains(id) {
            selectedExerciseIds.remove(id)
        } else {
            selectedExerciseIds.insert(id)
        }
    }
}
