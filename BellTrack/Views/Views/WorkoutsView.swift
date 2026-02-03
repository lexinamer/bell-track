import SwiftUI

struct WorkoutsView: View {

    @StateObject private var vm = WorkoutsViewModel()

    @State private var showingLog = false
    @State private var editingWorkout: Workout?

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            if vm.workouts.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(vm.workouts) { workout in
                        workoutRow(workout)
                    }
                    .onDelete { indexSet in
                        Task {
                            for index in indexSet {
                                await vm.deleteWorkout(id: vm.workouts[index].id)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Workouts")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingWorkout = nil
                    showingLog = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .fullScreenCover(isPresented: $showingLog) {
            LogWorkoutView(
                workout: editingWorkout,
                onSave: {
                    showingLog = false
                    Task { await vm.load() }
                },
                onCancel: {
                    showingLog = false
                }
            )
        }
        .task {
            await vm.load()
        }
    }

    // MARK: - Row

    private func workoutRow(_ workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {

            Text(workout.date.formatted(date: .abbreviated, time: .omitted))
                .font(Theme.Font.headline)

            Text(workout.logs.map { $0.exerciseName }.joined(separator: ", "))
                .font(Theme.Font.body)
                .foregroundColor(Color.brand.textSecondary)
        }
        .padding(.vertical, Theme.Space.sm)
        .contentShape(Rectangle())
        .onTapGesture {
            editingWorkout = workout
            showingLog = true
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: Theme.Space.md) {
            Image(systemName: "doc.plaintext")
                .font(.system(size: 40))
                .foregroundColor(Color.brand.textSecondary)

            Text("No workouts yet")
                .font(Theme.Font.headline)

            Text("Log your first workout.")
                .font(Theme.Font.body)
                .foregroundColor(Color.brand.textSecondary)
        }
    }
}
