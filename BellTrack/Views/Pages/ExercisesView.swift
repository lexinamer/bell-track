import SwiftUI

enum ExerciseTab: String, CaseIterable {
    case exercises = "Exercises"
    case complexes = "Complexes"
}

struct ExercisesView: View {

    @StateObject private var vm = ExercisesViewModel()

    @State private var selectedTab: ExerciseTab = .exercises
    @State private var editingExercise: Exercise?
    @State private var showingNewForm = false
    @State private var selectedExercise: Exercise?

    @State private var editingComplex: Complex?
    @State private var showingNewComplexForm = false
    @State private var selectedComplex: ResolvedComplex?
    @State private var exerciseToDelete: Exercise?
    @State private var complexToDelete: Complex?

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            if vm.isLoading && vm.exercises.isEmpty && vm.complexes.isEmpty {
                ProgressView()
            } else {
                VStack(spacing: 0) {

                    Picker("Category", selection: $selectedTab) {
                        ForEach(ExerciseTab.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if selectedTab == .exercises {
                        showingNewForm = true
                    } else {
                        showingNewComplexForm = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }

        // MARK: Sheets

        .sheet(item: $editingExercise) { exercise in
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
                onCancel: { editingExercise = nil }
            )
        }

        .sheet(isPresented: $showingNewForm) {
            ExerciseFormView(
                onSave: { name, primary, secondary in
                    Task {
                        await vm.saveExercise(
                            id: nil,
                            name: name,
                            primaryMuscles: primary,
                            secondaryMuscles: secondary
                        )
                        showingNewForm = false
                    }
                },
                onCancel: { showingNewForm = false }
            )
        }

        .sheet(isPresented: $showingNewComplexForm) {
            ComplexFormView(
                exercises: vm.exercises,
                onSave: { name, ids in
                    Task {
                        await vm.saveComplex(name: name, exerciseIds: ids)
                        showingNewComplexForm = false
                    }
                },
                onCancel: { showingNewComplexForm = false }
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
                onCancel: { editingComplex = nil }
            )
        }

        // MARK: Alerts

        .alert("Delete Exercise?", isPresented: .init(
            get: { exerciseToDelete != nil },
            set: { if !$0 { exerciseToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { }

            Button("Delete", role: .destructive) {
                if let exercise = exerciseToDelete {
                    Task { await vm.deleteExercise(id: exercise.id) }
                }
                exerciseToDelete = nil
            }
        } message: {
            Text("This will delete \"\(exerciseToDelete?.name ?? "")\".")
        }

        .alert("Delete Complex?", isPresented: .init(
            get: { complexToDelete != nil },
            set: { if !$0 { complexToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { }

            Button("Delete", role: .destructive) {
                if let complex = complexToDelete {
                    Task { await vm.deleteComplex(id: complex.id) }
                }
                complexToDelete = nil
            }
        } message: {
            Text("This will delete \"\(complexToDelete?.name ?? "")\".")
        }

        .task {
            await vm.load()
        }
    }

    // MARK: Exercises List

    private var exercisesList: some View {
        List {
            ForEach(vm.exercises) { exercise in
                exerciseRow(exercise)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: Complexes List

    private var complexesList: some View {
        List {
            ForEach(vm.resolvedComplexes) { resolved in
                complexRow(resolved)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: Exercise Row

    private func exerciseRow(_ exercise: Exercise) -> some View {

        SimpleCard(onTap: {
            selectedExercise = exercise
        }) {

            HStack {

                VStack(alignment: .leading, spacing: Theme.Space.xs) {

                    Text(exercise.name)
                        .font(Theme.Font.cardTitle)
                        .foregroundColor(.primary)

                }

                Spacer()

                HStack(spacing: Theme.Space.md) {

                    Button {
                        editingExercise = exercise
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(Color.brand.textSecondary)
                    }
                    .buttonStyle(.plain)


                    Button {
                        exerciseToDelete = exercise
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .padding(.horizontal)
        .padding(.vertical, Theme.Space.sm)
    }

    // MARK: Complex Row

    private func complexRow(_ resolved: ResolvedComplex) -> some View {

        SimpleCard {

            HStack {

                VStack(alignment: .leading, spacing: Theme.Space.xs) {

                    Text(resolved.name)
                        .font(Theme.Font.cardTitle)

                    let names = vm.exercises
                        .filter { resolved.exerciseIds.contains($0.id) }
                        .map { $0.name }
                        .joined(separator: " + ")

                    Text(names)
                        .font(Theme.Font.cardCaption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: Theme.Space.md) {

                    Button {
                        editingComplex =
                            vm.complexes.first { $0.id == resolved.id }
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(Color.brand.textSecondary)
                    }

                    Button {
                        complexToDelete =
                            vm.complexes.first { $0.id == resolved.id }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .padding(.horizontal)
        .padding(.vertical, Theme.Space.sm)
    }

    // MARK: Empty States (unchanged)

    private var exercisesEmptyState: some View {
        Text("No exercises")
    }

    private var complexesEmptyState: some View {
        Text("No complexes")
    }
}
