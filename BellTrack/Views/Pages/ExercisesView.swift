import SwiftUI

enum ExerciseTab: String, CaseIterable {
    case exercises = "Exercises"
    case complexes = "Complexes"
}

struct ExercisesView: View {

    @StateObject private var vm = ExercisesViewModel()

    @State private var selectedTab: ExerciseTab = .exercises

    @State private var selectedExercise: Exercise?
    @State private var selectedComplex: ResolvedComplex?

    @State private var editingExercise: Exercise?
    @State private var editingComplex: Complex?

    @State private var showingNewExerciseForm = false
    @State private var showingNewComplexForm = false

    @State private var exerciseToDelete: Exercise?
    @State private var complexToDelete: Complex?

    var body: some View {

        ZStack {

            Color.brand.background
                .ignoresSafeArea()

            if vm.isLoading && vm.exercises.isEmpty && vm.complexes.isEmpty {

                ProgressView()

            } else {

                VStack(spacing: 0) {

                    Picker("Category", selection: $selectedTab) {
                        ForEach(ExerciseTab.allCases, id: \.self) {
                            Text($0.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, Theme.Space.sm)

                    switch selectedTab {

                    case .exercises:
                        exercisesList

                    case .complexes:
                        complexesList
                    }
                }
            }
        }
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.large)

        // MARK: Navigation

        .navigationDestination(item: $selectedExercise) {
            ExerciseDetailView(exercise: $0)
        }

        .navigationDestination(item: $selectedComplex) {
            ExerciseDetailView(
                resolvedComplex: $0,
                exercises: vm.exercises
            )
        }

        // MARK: Toolbar

        .toolbar {

            ToolbarItem(placement: .topBarTrailing) {

                Button {

                    if selectedTab == .exercises {
                        showingNewExerciseForm = true
                    } else {
                        showingNewComplexForm = true
                    }

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
                            secondaryMuscles: secondary
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

        .fullScreenCover(isPresented: $showingNewComplexForm) {

            ComplexFormView(
                exercises: vm.exercises,
                onSave: { name, ids in

                    Task {

                        await vm.saveComplex(
                            name: name,
                            exerciseIds: ids
                        )

                        showingNewComplexForm = false
                    }
                },
                onCancel: {
                    showingNewComplexForm = false
                }
            )
        }

        .sheet(item: $editingComplex) { complex in

            ComplexFormView(
                complex: complex,
                exercises: vm.exercises,
                onSave: { name, ids in

                    Task {

                        await vm.saveComplex(
                            id: complex.id,
                            name: name,
                            exerciseIds: ids
                        )

                        editingComplex = nil
                    }
                },
                onCancel: {
                    editingComplex = nil
                }
            )
        }

        // MARK: Delete Alerts

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

        .alert("Delete Complex?", isPresented: .init(
            get: { complexToDelete != nil },
            set: { if !$0 { complexToDelete = nil } }
        )) {

            Button("Cancel", role: .cancel) {}

            Button("Delete", role: .destructive) {

                if let complex = complexToDelete {

                    Task {
                        await vm.deleteComplex(id: complex.id)
                    }
                }

                complexToDelete = nil
            }

        } message: {

            Text("This will permanently delete \"\(complexToDelete?.name ?? "")\".")
        }

        .task {
            await vm.load()
        }
    }

    // MARK: Exercises List

    private var exercisesList: some View {

        List {

            ForEach(vm.exercises) { exercise in

                SimpleCard(onTap: {

                    selectedExercise = exercise

                }) {

                    VStack(
                        alignment: .leading,
                        spacing: Theme.Space.xs
                    ) {

                        Text(exercise.name)
                            .font(Theme.Font.cardTitle)

                        MuscleTags(
                            primaryMuscles: exercise.primaryMuscles,
                            secondaryMuscles: []
                        )
                    }
                }
                .contextMenu {

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

    // MARK: Complexes List

    private var complexesList: some View {

        List {

            ForEach(vm.resolvedComplexes) { resolved in

                SimpleCard(onTap: {

                    selectedComplex = resolved

                }) {

                    VStack(
                        alignment: .leading,
                        spacing: Theme.Space.xs
                    ) {

                        Text(resolved.name)
                            .font(Theme.Font.cardTitle)

                        let names =
                            vm.exercises
                                .filter { resolved.exerciseIds.contains($0.id) }
                                .map { $0.name }
                                .joined(separator: " + ")

                        Text(names)
                            .font(Theme.Font.cardCaption)
                            .foregroundColor(.secondary)
                    }
                }
                .contextMenu {

                    Button {

                        editingComplex =
                            vm.complexes.first { $0.id == resolved.id }

                    } label: {

                        Label("Edit", systemImage: "pencil")
                    }

                    Button(role: .destructive) {

                        complexToDelete =
                            vm.complexes.first { $0.id == resolved.id }

                    } label: {

                        Label("Delete", systemImage: "trash")
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
