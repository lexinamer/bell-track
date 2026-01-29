import SwiftUI

struct LogWorkoutView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var blocks: [Block] = []
    @State private var selectedBlockID: String?
    @State private var selectedTemplateID: String?
    @State private var date: Date = Date()

    // exerciseID → trackingType → value
    @State private var results: [String: [TrackingType: String]] = [:]

    private var selectedBlock: Block? {
        blocks.first { $0.id == selectedBlockID }
    }

    private var selectedTemplate: WorkoutTemplate? {
        selectedBlock?.workouts.first { $0.id == selectedTemplateID }
    }

    var body: some View {
        NavigationStack {
            Form {

                // MARK: - Meta
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    Picker("Block", selection: $selectedBlockID) {
                        ForEach(blocks) { block in
                            Text(block.name).tag(Optional(block.id))
                        }
                    }

                    if let block = selectedBlock {
                        Picker("Workout", selection: $selectedTemplateID) {
                            ForEach(block.workouts) { workout in
                                Text("Workout \(workout.name)")
                                    .tag(Optional(workout.id))
                            }
                        }
                    }
                }

                // MARK: - Exercises
                if let template = selectedTemplate {
                    Section("Exercises") {
                        ForEach(template.exercises) { exercise in
                            VStack(alignment: .leading, spacing: Theme.Space.sm) {

                                Text(exercise.name)
                                    .font(Theme.Font.body)
                                    .foregroundColor(.brand.textPrimary)

                                ForEach(exercise.trackingTypes, id: \.self) { type in
                                    HStack {
                                        Text(type.label)
                                            .font(Theme.Font.meta)
                                            .foregroundColor(.brand.textSecondary)

                                        Spacer()

                                        TextField(
                                            type.placeholder,
                                            text: binding(
                                                exerciseID: exercise.id,
                                                type: type
                                            )
                                        )
                                        .multilineTextAlignment(.trailing)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 120)
                                    }
                                }
                            }
                            .padding(.vertical, Theme.Space.xs)
                        }
                    }
                }
            }
            .navigationTitle("Log Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(selectedTemplate == nil)
                }
            }
            .task {
                await load()
            }
            .onChange(of: selectedBlockID) { _, _ in
                selectedTemplateID = selectedBlock?.workouts.first?.id
                results.removeAll()
            }
        }
    }

    // MARK: - Data

    private func load() async {
        do {
            blocks = try await FirestoreService.shared.fetchBlocks()
            selectedBlockID = blocks.first?.id
            selectedTemplateID = blocks.first?.workouts.first?.id
        } catch {
            print(error)
        }
    }

    private func save() async {
        guard let block = selectedBlock,
              let template = selectedTemplate else { return }

        let exerciseResults = template.exercises.map {
            ExerciseResult(
                exerciseID: $0.id,
                values: results[$0.id] ?? [:]
            )
        }

        let workout = Workout(
            blockID: block.id,
            workoutTemplateID: template.id,
            workoutName: "Workout \(template.name)",
            date: date,
            results: exerciseResults
        )

        do {
            try await FirestoreService.shared.saveWorkout(workout)
            dismiss()
        } catch {
            print(error)
        }
    }

    // MARK: - Bindings

    private func binding(
        exerciseID: String,
        type: TrackingType
    ) -> Binding<String> {
        Binding {
            results[exerciseID]?[type] ?? ""
        } set: { newValue in
            if results[exerciseID] == nil {
                results[exerciseID] = [:]
            }
            results[exerciseID]?[type] = newValue
        }
    }
}

// MARK: - TrackingType helpers

private extension TrackingType {

    var label: String {
        rawValue.capitalized
    }

    var placeholder: String {
        switch self {
        case .reps: return "4x8"
        case .weight: return "12kg"
        case .time: return "1:30"
        case .effort: return "Low"
        }
    }
}
