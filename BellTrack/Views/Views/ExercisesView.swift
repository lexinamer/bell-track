import SwiftUI

struct ExercisesView: View {

    @StateObject private var vm = ExercisesViewModel()

    @State private var editingExercise: Exercise?
    @State private var showingNewForm = false
    @State private var selectedExercise: Exercise?

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Shared header component
                PageHeader(
                    title: "Exercises",
                    buttonText: "Add Exercise"
                ) {
                    showingNewForm = true
                }
                
                // Content
                if vm.isLoading && vm.exercises.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if vm.exercises.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    List {
                        ForEach(vm.exercises) { exercise in
                            exerciseCard(exercise)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("Edit") {
                                        editingExercise = exercise
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
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(Theme.Font.cardTitle)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                HStack {
                    Image(systemName: "dumbbell")
                        .font(Theme.Font.cardCaption)
                        .foregroundColor(.secondary)

                    Text("\(vm.workoutCounts[exercise.id] ?? 0) workouts")
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(.secondary)

                    Image(systemName: "clock")
                        .font(Theme.Font.cardCaption)
                        .foregroundColor(.secondary)

                    Text("\(vm.setCounts[exercise.id] ?? 0) sets")
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(.secondary)
                }

                if !exercise.primaryMuscles.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(exercise.primaryMuscles, id: \.self) { muscle in
                            Text(muscle.displayName)
                                .font(Theme.Font.cardCaption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.brand.primary.opacity(0.1))
                                .foregroundColor(Color.brand.primary)
                                .cornerRadius(10)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
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
