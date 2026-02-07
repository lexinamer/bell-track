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
                    // Segmented control
                    Picker("Category", selection: $selectedTab) {
                        ForEach(ExerciseTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, Theme.Space.sm)

                    // Tab content
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
        // Exercise sheets
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
                onCancel: {
                    editingExercise = nil
                }
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
                onCancel: {
                    showingNewForm = false
                }
            )
        }
        .sheet(item: $selectedExercise) { exercise in
            DetailView(exercise: exercise)
        }
        // Complex sheets
        .sheet(isPresented: $showingNewComplexForm) {
            ComplexFormView(
                exercises: vm.exercises,
                onSave: { name, exerciseIds in
                    Task {
                        await vm.saveComplex(name: name, exerciseIds: exerciseIds)
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
                onSave: { name, exerciseIds in
                    Task {
                        await vm.saveComplex(
                            id: complex.id,
                            name: name,
                            exerciseIds: exerciseIds
                        )
                        editingComplex = nil
                    }
                },
                onCancel: {
                    editingComplex = nil
                }
            )
        }
        .sheet(item: $selectedComplex) { resolved in
            complexDetailView(for: resolved)
        }
        .alert("Delete Complex?", isPresented: .init(
            get: { complexToDelete != nil },
            set: { if !$0 { complexToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { complexToDelete = nil }
            Button("Delete", role: .destructive) {
                if let complex = complexToDelete {
                    Task { await vm.deleteComplex(id: complex.id) }
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

    // MARK: - Exercises List

    private var exercisesList: some View {
        Group {
            if vm.exercises.isEmpty {
                exercisesEmptyState
            } else {
                List {
                    Button {
                        showingNewForm = true
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Exercise")
                        }
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(Color.brand.primary)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    ForEach(vm.exercises) { exercise in
                        exerciseCard(exercise)
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
        }
    }

    // MARK: - Complexes List

    private var complexesList: some View {
        Group {
            if vm.resolvedComplexes.isEmpty {
                complexesEmptyState
            } else {
                List {
                    Button {
                        showingNewComplexForm = true
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Complex")
                        }
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(Color.brand.primary)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    ForEach(vm.resolvedComplexes) { resolved in
                        complexCard(resolved)
                            .contextMenu {
                                Button {
                                    editingComplex = vm.complexes.first { $0.id == resolved.id }
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    complexToDelete = vm.complexes.first { $0.id == resolved.id }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                        .foregroundColor(.red)
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
    }

    // MARK: - Exercise Card

    private func exerciseCard(_ exercise: Exercise) -> some View {
        SimpleCard(onTap: {
            selectedExercise = exercise
        }) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(exercise.name)
                    .font(Theme.Font.cardTitle)
                    .foregroundColor(.primary)
                    .lineLimit(2)

//                MuscleTagsView(
//                    primaryMuscles: exercise.primaryMuscles,
//                    secondaryMuscles: exercise.secondaryMuscles
//                )
//                .padding(.top, Theme.Space.xs)
            }
        }
    }

    // MARK: - Complex Card

    private func complexCard(_ resolved: ResolvedComplex) -> some View {
        SimpleCard(onTap: {
            selectedComplex = resolved
        }) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                HStack {
                    Text(resolved.name)
                        .font(Theme.Font.cardTitle)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }

                // Component exercise names
                let componentNames = vm.exercises
                    .filter { resolved.exerciseIds.contains($0.id) }
                    .map { $0.name }
                    .joined(separator: " + ")

                Text(componentNames)
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

//                MuscleTagsView(
//                    primaryMuscles: resolved.primaryMuscles,
//                    secondaryMuscles: resolved.secondaryMuscles
//                )
//                .padding(.top, Theme.Space.xs)
            }
        }
    }

    // MARK: - Complex Detail Helper

    private func complexDetailView(for resolved: ResolvedComplex) -> DetailView {
        DetailView(resolvedComplex: resolved, exercises: vm.exercises)
    }

    // MARK: - Empty States

    private var exercisesEmptyState: some View {
        VStack(spacing: Theme.Space.mdp) {
            Spacer()

            Image(systemName: "dumbbell")
                .font(.system(size: Theme.IconSize.xl))
                .foregroundColor(.secondary)

            Text("No exercises yet")
                .font(Theme.Font.cardTitle)

            Text("Add your first exercise to get started.")
                .font(Theme.Font.cardSecondary)
                .foregroundColor(.secondary)

            Button {
                showingNewForm = true
            } label: {
                Text("Add Exercise")
                    .font(Theme.Font.buttonPrimary)
                    .foregroundColor(.white)
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.vertical, Theme.Space.smp)
                    .background(Color.brand.primary)
                    .cornerRadius(Theme.Radius.md)
            }
            .padding(.top, Theme.Space.sm)

            Spacer()
        }
    }

    private var complexesEmptyState: some View {
        VStack(spacing: Theme.Space.mdp) {
            Spacer()

            Image(systemName: "link")
                .font(.system(size: Theme.IconSize.xl))
                .foregroundColor(.secondary)

            Text("No complexes yet")
                .font(Theme.Font.cardTitle)

            Text("Combine exercises into compound movements.")
                .font(Theme.Font.cardSecondary)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingNewComplexForm = true
            } label: {
                Text("Add Complex")
                    .font(Theme.Font.buttonPrimary)
                    .foregroundColor(.white)
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.vertical, Theme.Space.smp)
                    .background(Color.brand.primary)
                    .cornerRadius(Theme.Radius.md)
            }
            .padding(.top, Theme.Space.sm)

            Spacer()
        }
    }
}
