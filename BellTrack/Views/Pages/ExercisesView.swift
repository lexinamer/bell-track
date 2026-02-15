import SwiftUI

struct ExercisesView: View {

    @StateObject private var vm = ExercisesViewModel()

    @State private var selectedExercise: Exercise?
    @State private var editingExercise: Exercise?
    @State private var showingNewExerciseForm = false
    @State private var exerciseToDelete: Exercise?

    var body: some View {

        ZStack {

            Color.brand.background
                .ignoresSafeArea()

            if vm.isLoading && vm.exercises.isEmpty {

                ProgressView()

            } else {

                List {

                    ForEach(vm.exercises) { exercise in

                        SimpleCard(onTap: {

                            selectedExercise = exercise

                        }) {

                            HStack(alignment: .top, spacing: Theme.Space.md) {

                                VStack(
                                    alignment: .leading,
                                    spacing: Theme.Space.xs
                                ) {

                                    Text(exercise.name)
                                        .font(Theme.Font.cardTitle)

                                    if let exerciseIds = exercise.exerciseIds, !exerciseIds.isEmpty {

                                        let names = vm.exercises
                                            .filter { exerciseIds.contains($0.id) }
                                            .map { $0.name }
                                            .joined(separator: " + ")

                                        Text(names)
                                            .font(Theme.Font.cardCaption)
                                            .foregroundColor(Color.brand.textSecondary)

                                    } else {

                                        MuscleTags(
                                            primaryMuscles: exercise.primaryMuscles,
                                            secondaryMuscles: []
                                        )
                                    }
                                }

                                Spacer()

                                Menu {

                                    Button {

                                        editingExercise = exercise

                                    } label: {

                                        Label("Edit", systemImage: "pencil")
                                    }

                                    Button(role: .destructive) {

                                        exerciseToDelete = exercise

                                    } label: {

                                        Label("Delete", systemImage: "trash")
                                    }

                                } label: {

                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color.brand.textSecondary)
                                        .frame(width: 32, height: 32)
                                        .contentShape(Rectangle())
                                }
                            }
                        }
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
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.large)

        // MARK: Navigation

        .navigationDestination(item: $selectedExercise) {
            ExerciseDetailView(exercise: $0)
        }

        // MARK: Toolbar

        .toolbar {

            ToolbarItem(placement: .topBarTrailing) {

                Button {
                    showingNewExerciseForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }

        // MARK: Forms

        .fullScreenCover(item: $editingExercise) { exercise in

            ExerciseFormView(
                exercise: exercise,
                onSave: { name, primary, secondary in

                    Task {

                        await vm.saveExercise(
                            id: exercise.id,
                            name: name,
                            primaryMuscles: primary,
                            secondaryMuscles: secondary,
                            exerciseIds: exercise.exerciseIds
                        )

                        editingExercise = nil
                    }
                },
                onCancel: {
                    editingExercise = nil
                }
            )
        }

        .fullScreenCover(isPresented: $showingNewExerciseForm) {

            ExerciseFormView(
                onSave: { name, primary, secondary in

                    Task {

                        await vm.saveExercise(
                            id: nil,
                            name: name,
                            primaryMuscles: primary,
                            secondaryMuscles: secondary
                        )

                        showingNewExerciseForm = false
                    }
                },
                onCancel: {
                    showingNewExerciseForm = false
                }
            )
        }

        // MARK: Delete Alert

        .alert("Delete Exercise?", isPresented: .init(
            get: { exerciseToDelete != nil },
            set: { if !$0 { exerciseToDelete = nil } }
        )) {

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

        .task {
            await vm.load()
        }
    }
}
