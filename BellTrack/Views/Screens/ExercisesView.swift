import SwiftUI

struct ExercisesView: View {
    
    @StateObject private var vm = ExercisesViewModel()
    
    @State private var selectedExercise: Exercise?
    @State private var editingExercise: Exercise?
    @State private var showingNewExerciseForm = false
    @State private var exerciseToDelete: Exercise?
    
    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()
            
            if vm.isLoading && vm.exercises.isEmpty {
                ProgressView()

            } else {
                List {
                    ForEach(Array(vm.exercises.enumerated()), id: \.element.id) { exerciseIndex, exercise in
                        ExerciseCard(
                            exercise: exercise,
                            accentColor: BlockColorPalette.templateColor(
                                blockIndex: 0,
                                templateIndex: exerciseIndex
                            ),
                            onTap: {
                                selectedExercise = exercise
                            },
                            onEdit: {
                                editingExercise = exercise
                            },
                            onDelete: {
                                exerciseToDelete = exercise
                            }
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.horizontal)
                        .padding(.vertical, Theme.Space.sm)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .task {
            await vm.load()
        }
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.large)
        
        // Tap → detail
        .navigationDestination(item: $selectedExercise) {
            ExerciseDetailView(exercise: $0)
        }
        
        // + button → new exercise
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNewExerciseForm = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                }
            }
        }
        
        // MARK: - Edit Exercises
        .fullScreenCover(item: $editingExercise) { exercise in
            ExerciseFormView(
                exercise: exercise,
                onSave: { name, primary, secondary, mode in
                    Task {
                        await vm.saveExercise(
                            id: exercise.id,
                            name: name,
                            primaryMuscles: primary,
                            secondaryMuscles: secondary,
                            mode: mode
                        )
                        editingExercise = nil
                    }
                },
                onCancel: {
                    editingExercise = nil
                }
            )
        }
        
        // MARK: - New Exercise
        .fullScreenCover(isPresented: $showingNewExerciseForm) {
            ExerciseFormView(
                onSave: { name, primary, secondary, mode in
                    Task {
                        await vm.saveExercise(
                            id: nil,
                            name: name,
                            primaryMuscles: primary,
                            secondaryMuscles: secondary,
                            mode: mode
                        )
                        showingNewExerciseForm = false
                    }
                },
                onCancel: {
                    showingNewExerciseForm = false
                }
            )
        }
        
        // MARK: - Delete Exercises
        .alert(
            "Delete Exercise?",
            isPresented: Binding(
                get: { exerciseToDelete != nil },
                set: { if !$0 { exerciseToDelete = nil } }
            )
        ) {
            
            Button("Cancel", role: .cancel) {}
            
            Button("Delete", role: .destructive) {
                if let exercise = exerciseToDelete {
                    Task {
                        await vm.deleteExercise(id: exercise.id)
                    }
                }
                exerciseToDelete = nil
            }
            
        } message: {
            Text("This will permanently delete \"\(exerciseToDelete?.name ?? "")\".")
        }
    }
}
