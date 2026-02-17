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

            VStack(spacing: 0) {
                LargeTitleHeader(title: "Exercises")

                if vm.isLoading && vm.exercises.isEmpty {

                    ProgressView()

                } else {

                    List {

                    ForEach(vm.exercises) { exercise in

                        ExerciseCard(onTap: {

                            selectedExercise = exercise

                        }) {

                            HStack(alignment: .top, spacing: Theme.Space.md) {

                                VStack(
                                    alignment: .leading,
                                    spacing: Theme.Space.xs
                                ) {

                                    Text(exercise.name)
                                        .font(Theme.Font.cardTitle)

                                    MuscleTags(
                                        primaryMuscles: exercise.primaryMuscles,
                                        secondaryMuscles: exercise.secondaryMuscles
                                    )
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
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)

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

// MARK: - Exercise Card (Private Component)

private struct ExerciseCard<Content: View>: View {

    let content: Content
    let onTap: (() -> Void)?

    init(
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.onTap = onTap
        self.content = content()
    }

    var body: some View {

        VStack(alignment: .leading, spacing: Theme.Space.md) {
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: Theme.Radius.md))
        .shadow(
            color: .black.opacity(0.05),
            radius: 2,
            x: 0,
            y: 1
        )
        .modifier(CardTapModifier(onTap: onTap))
    }
}

// MARK: - Tap modifier that DOES NOT break buttons

private struct CardTapModifier: ViewModifier {

    let onTap: (() -> Void)?

    func body(content: Content) -> some View {

        if let onTap {
            content
                .contentShape(Rectangle())
                .simultaneousGesture(
                    TapGesture().onEnded {
                        onTap()
                    }
                )
        } else {
            content
        }
    }
}
