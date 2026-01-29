import SwiftUI

struct SaveBlockView: View {

    @Environment(\.dismiss) private var dismiss

    let existingBlock: Block?

    @State private var name: String
    @State private var startDate: Date
    @State private var durationWeeks: Int
    @State private var workouts: [WorkoutTemplate]

    private let durations = [2, 4, 6, 8]

    init(block: Block? = nil) {
        self.existingBlock = block
        _name = State(initialValue: block?.name ?? "")
        _startDate = State(initialValue: block?.startDate ?? Date())
        _durationWeeks = State(initialValue: block?.durationWeeks ?? 6)
        _workouts = State(initialValue: block?.workouts ?? [])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {

                    // MARK: - Meta
                    VStack(alignment: .leading, spacing: Theme.Space.md) {

                        TextField("Block name", text: $name)
                            .font(Theme.Font.body)
                            .padding()
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .cornerRadius(Theme.Radius.sm)

                        DatePicker(
                            "Start date",
                            selection: $startDate,
                            displayedComponents: .date
                        )

                        HStack(spacing: Theme.Space.sm) {
                            ForEach(durations, id: \.self) { weeks in
                                Button {
                                    durationWeeks = weeks
                                } label: {
                                    Text("\(weeks)w")
                                        .font(Theme.Font.meta)
                                        .foregroundColor(durationWeeks == weeks ? .white : .primary)
                                        .padding(.horizontal, Theme.Space.md)
                                        .padding(.vertical, Theme.Space.sm)
                                        .background(durationWeeks == weeks ? Color.blue : Color.gray.opacity(0.2))
                                        .cornerRadius(Theme.Radius.sm)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // MARK: - Workouts
                    VStack(alignment: .leading, spacing: Theme.Space.md) {

                        Text("Workouts")
                            .font(Theme.Font.title)

                        ForEach(workouts.indices, id: \.self) { index in
                            workoutEditor(workout: $workouts[index])
                        }

                        Button {
                            workouts.append(
                                WorkoutTemplate(
                                    id: UUID().uuidString,
                                    name: "\(workouts.count + 1)",
                                    exercises: []
                                )
                            )
                        } label: {
                            Text("Add Workout")
                                .font(Theme.Font.link)
                        }
                    }

                    // MARK: - Delete
                    if let block = existingBlock {
                        Button(role: .destructive) {
                            Task {
                                try? await FirestoreService.shared.deleteBlock(blockID: block.id)
                                dismiss()
                            }
                        } label: {
                            Text("Delete Block")
                        }
                    }
                }
                .padding(Theme.Space.md)
            }
            .navigationTitle(existingBlock == nil ? "New Block" : "Edit Block")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Save

    private func save() async {
        let block = Block(
            id: existingBlock?.id ?? UUID().uuidString,
            name: name,
            startDate: startDate,
            durationWeeks: durationWeeks,
            workouts: workouts
        )

        try? await FirestoreService.shared.saveBlock(block)
        dismiss()
    }

    // MARK: - Workout Editor

    @ViewBuilder
    private func workoutEditor(
        workout: Binding<WorkoutTemplate>
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {

            TextField("Workout name", text: workout.name)
                .font(Theme.Font.body)
                .padding()
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(Theme.Radius.sm)

            ForEach(workout.wrappedValue.exercises.indices, id: \.self) { index in
                exerciseEditor(
                    exercise: Binding(
                        get: {
                            workout.wrappedValue.exercises[index]
                        },
                        set: {
                            workout.wrappedValue.exercises[index] = $0
                        }
                    )
                )
            }

            Button {
                workout.wrappedValue.exercises.append(
                    Exercise(
                        id: UUID().uuidString,
                        name: "",
                        trackingTypes: []
                    )
                )
            } label: {
                Text("Add Exercise")
                    .font(Theme.Font.link)
            }
        }
        .padding()
        .background(Color.brand.background)
        .cornerRadius(Theme.Radius.sm)
    }

    // MARK: - Exercise Editor

    @ViewBuilder
    private func exerciseEditor(
        exercise: Binding<Exercise>
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {

            TextField("Exercise name", text: exercise.name)
                .font(Theme.Font.body)
                .padding()
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(Theme.Radius.sm)

            HStack(spacing: Theme.Space.sm) {
                ForEach(TrackingType.allCases, id: \.self) { type in
                    Button {
                        toggleTracking(type, for: exercise)
                    } label: {
                        let isSelected = exercise.wrappedValue.trackingTypes.contains(type)
                        Text(type.rawValue.capitalized)
                            .font(Theme.Font.meta)
                            .foregroundColor(isSelected ? .white : .primary)
                            .padding(.horizontal, Theme.Space.sm)
                            .padding(.vertical, Theme.Space.xs)
                            .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                            .cornerRadius(Theme.Radius.sm)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Tracking Toggle

    private func toggleTracking(
        _ type: TrackingType,
        for exercise: Binding<Exercise>
    ) {
        if exercise.wrappedValue.trackingTypes.contains(type) {
            exercise.wrappedValue.trackingTypes.removeAll { $0 == type }
        } else {
            exercise.wrappedValue.trackingTypes.append(type)
        }
    }
}
