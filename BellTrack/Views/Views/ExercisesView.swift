import SwiftUI

struct ExercisesView: View {

    @StateObject private var vm = ExercisesViewModel()

    @State private var editingExercise: Exercise?
    @State private var showingNewForm = false
    @State private var selectedExercise: Exercise?

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            // Content
            if vm.isLoading && vm.exercises.isEmpty {
                ProgressView()
            } else if vm.exercises.isEmpty {
                emptyState
            } else {
                List {
                    // Add exercise link at top
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
        .task {
            await vm.load()
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

                let allMuscles: [(muscle: MuscleGroup, isPrimary: Bool)] =
                    exercise.primaryMuscles.map { ($0, true) } +
                    exercise.secondaryMuscles.map { ($0, false) }

                if !allMuscles.isEmpty {
                    FlowLayout(spacing: Theme.Space.xs) {
                        ForEach(Array(allMuscles.enumerated()), id: \.offset) { _, item in
                            muscleTag(item.muscle.displayName, isPrimary: item.isPrimary)
                        }
                    }
                    .padding(.top, Theme.Space.xs)
                }
            }
        }
    }

    // MARK: - Muscle Tag

    private func muscleTag(_ name: String, isPrimary: Bool) -> some View {
        Text(name)
            .font(Theme.Font.cardCaption)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                isPrimary
                    ? Color.brand.primary
                    : Color.brand.primary.opacity(0.55)
            )
            .foregroundColor(.white)
            .cornerRadius(10)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Space.mdp) {
            Image(systemName: "dumbbell")
                .font(.system(size: Theme.IconSize.xl))
                .foregroundColor(.secondary)

            Text("No exercises yet")
                .font(Theme.Font.cardTitle)

            Text("Add your first exercise.")
                .font(Theme.Font.cardSecondary)
                .foregroundColor(.secondary)
        }
    }
}
