import SwiftUI

struct DetailView: View {
    let title: String
    let filterType: DetailFilterType
    let filterId: String?

    @Environment(\.dismiss) private var dismiss

    // Block mode: workouts grouped by date (each workout's logs listed)
    @State private var workoutsByDate: [(date: Date, name: String?, logs: [(exerciseName: String, details: String, note: String?)])] = []
    // Exercise mode: flat list of that exercise across all time
    @State private var exerciseEntries: [(date: Date, details: String, note: String?)] = []
    @State private var isLoading = true
    private let firestore = FirestoreService()

    enum DetailFilterType {
        case block(Block)
        case exercise(Exercise)
        case allTime
    }

    // Convenience initializers
    init(block: Block) {
        self.title = block.name
        self.filterType = .block(block)
        self.filterId = block.id
    }

    init(exercise: Exercise) {
        self.title = exercise.name
        self.filterType = .exercise(exercise)
        self.filterId = exercise.id
    }

    private var isEmpty: Bool {
        switch filterType {
        case .block, .allTime:
            return workoutsByDate.isEmpty
        case .exercise:
            return exerciseEntries.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading workouts...")
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isEmpty {
                    VStack(spacing: 16) {
                        Text("No workouts found")
                            .font(Theme.Font.cardTitle)
                            .foregroundColor(.secondary)

                        Text(emptyStateMessage)
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        // Block notes section
                        if case .block(let block) = filterType, let notes = block.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Block Notes")
                                    .font(Theme.Font.cardTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 20)

                                Text(notes)
                                    .font(Theme.Font.cardSecondary)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 8)
                            }
                        }

                        switch filterType {
                        case .block, .allTime:
                            // Show workouts grouped by date (newest first)
                            ForEach(Array(workoutsByDate.enumerated()), id: \.offset) { _, workout in
                                workoutDateSection(date: workout.date, name: workout.name, logs: workout.logs)
                            }
                        case .exercise:
                            // Show that exercise across all time (newest first)
                            exerciseHistorySection(entries: exerciseEntries)
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadWorkoutData()
        }
    }

    // MARK: - Empty State Message

    private var emptyStateMessage: String {
        switch filterType {
        case .block:
            return "Workouts need to have this block assigned to show up here."
        case .exercise:
            return "No workouts found with this exercise."
        case .allTime:
            return "No workouts found."
        }
    }

    // MARK: - Block Mode: Workout Date Section

    private func workoutDateSection(date: Date, name: String?, logs: [(exerciseName: String, details: String, note: String?)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(date.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(Theme.Font.cardTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                if let name = name, !name.isEmpty {
                    Text(name)
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(logs.enumerated()), id: \.offset) { _, log in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .top, spacing: 16) {
                            // Exercise name
                            Text(log.exerciseName)
                                .font(Theme.Font.cardSecondary)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .frame(width: 120, alignment: .leading)

                            // Details
                            Text(log.details.isEmpty ? "No details" : log.details)
                                .font(Theme.Font.cardSecondary)
                                .foregroundColor(.primary)

                            Spacer()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 1)
                }
            }
        }
    }

    // MARK: - Exercise Mode: History Section

    private func exerciseHistorySection(entries: [(date: Date, details: String, note: String?)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .top, spacing: 16) {
                            // Date
                            Text(entry.date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(Theme.Font.cardSecondary)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .frame(width: 70, alignment: .leading)

                            // Details
                            Text(entry.details.isEmpty ? "No details" : entry.details)
                                .font(Theme.Font.cardSecondary)
                                .foregroundColor(.primary)

                            Spacer()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 1)
                }
            }
        }
    }

    // MARK: - Load Data

    private func loadWorkoutData() async {
        do {
            let workouts = try await firestore.fetchWorkouts()

            // Filter workouts based on type
            let filteredWorkouts: [Workout]
            switch filterType {
            case .block(let block):
                filteredWorkouts = workouts.filter { $0.blockId == block.id }
            case .exercise(let exercise):
                filteredWorkouts = workouts.filter { workout in
                    workout.logs.contains { $0.exerciseId == exercise.id }
                }
            case .allTime:
                filteredWorkouts = workouts
            }

            switch filterType {
            case .block, .allTime:
                // Group by workout date, newest first
                let sorted = filteredWorkouts.sorted { $0.date > $1.date }
                var result: [(date: Date, name: String?, logs: [(exerciseName: String, details: String, note: String?)])] = []
                for w in sorted {
                    let logs = w.logs.map { log in
                        (exerciseName: log.exerciseName, details: formatWorkoutDetails(log), note: log.note)
                    }
                    result.append((date: w.date, name: w.name, logs: logs))
                }
                self.workoutsByDate = result

            case .exercise(let exercise):
                // Flat list of that exercise across all time, newest first
                var entries: [(date: Date, details: String, note: String?)] = []
                for workout in filteredWorkouts {
                    for log in workout.logs where log.exerciseId == exercise.id {
                        entries.append((date: workout.date, details: formatWorkoutDetails(log), note: log.note))
                    }
                }
                entries.sort { $0.date > $1.date }
                self.exerciseEntries = entries
            }

            self.isLoading = false

        } catch {
            print("❌ Failed to load workout data:", error)
            self.isLoading = false
        }
    }

    // MARK: - Format Details

    private func formatWorkoutDetails(_ log: WorkoutLog) -> String {
        var components: [String] = []

        // Sets and Reps
        if let sets = log.sets, sets > 0 {
            if let reps = log.reps, !reps.isEmpty {
                components.append("\(sets)x\(reps)")
            } else {
                components.append("\(sets) sets")
            }
        }

        // Weight
        if let weight = log.weight, !weight.isEmpty {
            components.append("\(weight)kg")
        }

        // Notes
        if let note = log.note, !note.isEmpty {
            components.append(note)
        }

        return components.joined(separator: " • ")
    }
}
