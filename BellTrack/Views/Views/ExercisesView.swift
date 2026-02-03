import SwiftUI

struct ExercisesView: View {

    @StateObject private var vm = ExercisesViewModel()

    @State private var showingForm = false
    @State private var editingExercise: Exercise?
    @State private var nameInput = ""

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            if vm.exercises.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(vm.exercises) { exercise in
                        Button {
                            editingExercise = exercise
                            nameInput = exercise.name
                            showingForm = true
                        } label: {
                            Text(exercise.name)
                                .font(Theme.Font.body)
                                .foregroundColor(Color.brand.textPrimary)
                        }
                    }
                    .onDelete { indexSet in
                        Task {
                            for index in indexSet {
                                let id = vm.exercises[index].id
                                await vm.deleteExercise(id: id)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingExercise = nil
                    nameInput = ""
                    showingForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            exerciseForm
        }
        .task {
            await vm.load()
        }
    }

    // MARK: - Form

    private var exerciseForm: some View {
        NavigationStack {
            VStack(spacing: Theme.Space.md) {

                TextField("Exercise name", text: $nameInput)
                    .textFieldStyle(.roundedBorder)

                Spacer()
            }
            .padding(Theme.Space.md)
            .background(Color.brand.background)
            .navigationTitle(editingExercise == nil ? "New Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismissForm()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await vm.saveExercise(
                                id: editingExercise?.id,
                                name: nameInput
                            )
                            dismissForm()
                        }
                    }
                    .disabled(nameInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func dismissForm() {
        showingForm = false
        editingExercise = nil
        nameInput = ""
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: Theme.Space.md) {
            Image(systemName: "dumbbell")
                .font(.system(size: 40))
                .foregroundColor(Color.brand.textSecondary)

            Text("No exercises yet")
                .font(Theme.Font.headline)

            Text("Add your first exercise.")
                .font(Theme.Font.body)
                .foregroundColor(Color.brand.textSecondary)
        }
    }
}
