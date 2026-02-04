import SwiftUI

struct ExercisesView: View {

    @StateObject private var vm = ExercisesViewModel()

    @State private var showingForm = false
    @State private var editingExercise: Exercise?
    @State private var showingDetail = false
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
                    editingExercise = nil
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
                            exerciseCard(exercise)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("Edit") {
                                        editingExercise = exercise
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
            ExerciseFormView(
                exercise: editingExercise,
                onSave: { name in
                    Task {
                        await vm.saveExercise(
                            id: editingExercise?.id,
                            name: name
                        )
                        dismissForm()
                    }
                },
                onCancel: {
                    dismissForm()
                }
            )
        }
        .sheet(isPresented: $showingDetail) {
            if let exercise = selectedExercise {
                DetailView(exercise: exercise)
            }
        }
        .task {
            await vm.load()
        }
    }

    // MARK: - Exercise Card

    private func exerciseCard(_ exercise: Exercise) -> some View {
        SimpleCard(onTap: {
            selectedExercise = exercise
            showingDetail = true
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
            }
        }
    }

    private func dismissForm() {
        showingForm = false
        editingExercise = nil
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
