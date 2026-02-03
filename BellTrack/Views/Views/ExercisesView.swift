import SwiftUI

struct ExercisesView: View {

    @StateObject private var vm = ExercisesViewModel()

    @State private var showingForm = false
    @State private var editingExercise: Exercise?
    @State private var nameInput = ""

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Shared header component
                PageHeader(
                    title: "Exercises",
                    buttonText: "Add Exercise"
                ) {
                    editingExercise = nil
                    nameInput = ""
                    showingForm = true
                }
                
                // Content
                if vm.exercises.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    List {
                        ForEach(vm.exercises) { exercise in
                            exerciseRow(exercise)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("Delete", role: .destructive) {
                                        Task {
                                            await vm.deleteExercise(id: exercise.id)
                                        }
                                    }
                                    .tint(.red)
                                    
                                    Button("Edit") {
                                        editingExercise = exercise
                                        nameInput = exercise.name
                                        showingForm = true
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
            exerciseForm
        }
        .task {
            await vm.load()
        }
    }

    // MARK: - Exercise Row

    private func exerciseRow(_ exercise: Exercise) -> some View {
        HStack {
            Text(exercise.name)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .contentShape(Rectangle())
        .onTapGesture {
            editingExercise = exercise
            nameInput = exercise.name
            showingForm = true
        }
    }

    // MARK: - Form

    private var exerciseForm: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Exercise name", text: $nameInput)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "dumbbell")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No exercises yet")
                .font(.headline)

            Text("Add your first exercise.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}
