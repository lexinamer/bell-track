import SwiftUI

struct ExerciseFormView: View {
    let exercise: Exercise?
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    @State private var nameInput: String
    
    init(
        exercise: Exercise? = nil,
        onSave: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.exercise = exercise
        self.onSave = onSave
        self.onCancel = onCancel
        self._nameInput = State(initialValue: exercise?.name ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Exercise name", text: $nameInput)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(exercise == nil ? "New Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(nameInput)
                    }
                    .disabled(nameInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    ExerciseFormView(
        exercise: nil,
        onSave: { name in
            print("Save exercise: \(name)")
        },
        onCancel: {
            print("Cancel")
        }
    )
}
