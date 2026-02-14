import SwiftUI

struct WorkoutFormView: View {

    let workout: Workout?
    let onSave: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    @State private var blockId: String?
    @State private var logs: [WorkoutLog]
    @State private var exercises: [Exercise] = []
    @State private var complexes: [Complex] = []
    @State private var blocks: [Block] = []
    @State private var templates: [WorkoutTemplate] = []
    @State private var workouts: [Workout] = []
    @State private var selectedTemplateId: String? = nil
    @State private var showingNotes: [String: Bool] = [:]

    private let firestore = FirestoreService()

    // MARK: - Init

    init(
        workout: Workout?,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.workout = workout
        self.onSave = onSave
        self.onCancel = onCancel

        _date = State(initialValue: workout?.date ?? Date())
        _blockId = State(initialValue: workout?.blockId)
        _logs = State(initialValue: workout?.logs ?? [])
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {

                    // MARK: - Meta Section
                    VStack(spacing: 0) {
                        // Date Picker
                        HStack {
                            Text("Date")
                            Spacer()
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))

                        Divider()
                            .padding(.leading, 16)

                        // Block Selector
                        if !blocks.isEmpty {
                            HStack {
                                Text("Block")
                                Spacer()

                                Picker("Block", selection: $blockId) {
                                    ForEach(blocks) { block in
                                        Text(block.name)
                                            .tag(Optional(block.id))
                                    }
                                }
                                .pickerStyle(.menu)
                                .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemBackground))
                        } else {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text("Create a block first to log workouts.")
                                    .font(Theme.Font.cardSecondary)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemBackground))
                        }

                        // Template Selector (only when a block is selected and has templates)
                        if let currentBlockId = blockId {
                            let blockTemplates = templates.filter { $0.blockId == currentBlockId }
                            if !blockTemplates.isEmpty {
                                Divider()
                                    .padding(.leading, 16)

                                HStack {
                                    Text("Template")
                                    Spacer()

                                    Picker("Template", selection: $selectedTemplateId) {
                                        Text("None")
                                            .tag(String?.none)
                                        ForEach(blockTemplates) { template in
                                            Text(template.name)
                                                .tag(Optional(template.id))
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.systemBackground))
                            }
                        }
                    }
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // MARK: - Exercises Section
                    VStack(spacing: Theme.Space.mdp) {
                        ForEach($logs) { $log in
                            exerciseCard(log: $log)
                        }

                        Button(action: addLog) {
                            HStack(spacing: Theme.Space.sm) {
                                Image(systemName: "plus")
                                    .font(.system(size: Theme.IconSize.sm))
                                Text("Add Exercise")
                                    .font(.system(size: Theme.IconSize.sm))
                            }
                            .foregroundColor(Color.brand.primary)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Log Workout")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: blockId) { _, newBlockId in
                selectedTemplateId = nil
                if let newBlockId {
                    selectedTemplateId =
                        templates.first(where: { $0.blockId == newBlockId })?.id
                }
            }
            .onChange(of: selectedTemplateId) { _, newTemplateId in
                guard let templateId = newTemplateId,
                      let template = templates.first(where: { $0.id == templateId })
                else { return }

                logs = template.entries.map { entry in
                    let recent = mostRecentLog(
                        exerciseId: entry.exerciseId,
                        isComplex: entry.isComplex
                    )

                    return WorkoutLog(
                        id: UUID().uuidString,
                        exerciseId: entry.exerciseId,
                        exerciseName: entry.exerciseName,
                        isComplex: entry.isComplex,
                        sets: recent?.sets,
                        reps: recent?.reps,
                        weight: recent?.weight,
                        note: nil
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await save()
                            onSave()
                            dismiss()
                        }
                    }
                    .disabled(logs.isEmpty || blockId == nil)
                }
            }
            .task {
                await loadReferenceData()
            }
        }
    }

    // MARK: - Exercise Card

    private func exerciseCard(log: Binding<WorkoutLog>) -> some View {
        let logId = log.wrappedValue.id

        return VStack(spacing: Theme.Space.md) {

            // Header: exercise picker + action icons
            HStack {
                if log.exerciseName.wrappedValue.isEmpty {
                    // No exercise selected — show picker
                    Menu {
                        if !complexes.isEmpty {
                            Section("Complexes") {
                                ForEach(complexes) { complex in
                                    Button {
                                        log.exerciseId.wrappedValue = complex.id
                                        log.exerciseName.wrappedValue = complex.name
                                        log.isComplex.wrappedValue = true
                                    } label: {
                                        Label(complex.name, systemImage: "rectangle.stack")
                                    }
                                }
                            }
                        }

                        Section("Exercises") {
                            ForEach(exercises) { exercise in
                                Button {
                                    log.exerciseId.wrappedValue = exercise.id
                                    log.exerciseName.wrappedValue = exercise.name
                                    log.isComplex.wrappedValue = false
                                } label: {
                                    Text(exercise.name)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Select exercise")
                                .font(Theme.Font.cardTitle)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    // Exercise already set — just show name
                    Text(log.exerciseName.wrappedValue)
                        .font(Theme.Font.cardTitle)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }

                Spacer()

                // Note toggle
                Button {
                    showingNotes[logId] = !(showingNotes[logId] ?? false)
                } label: {
                    Image(systemName: "square.and.pencil")
                        .foregroundColor(.gray)
                        .font(Theme.Font.cardSecondary)
                }
                .buttonStyle(PlainButtonStyle())

                // Delete log
                Button {
                    removeLog(logId)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(Theme.Font.cardTitle)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Single row layout: Sets | Reps/Time | Weight
            HStack(spacing: Theme.Space.md) {
                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    Text("Sets")
                        .font(Theme.Font.cardSecondary)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    TextField("5", value: log.sets, format: .number)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }

                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    Text("Reps/Time")
                        .font(Theme.Font.cardSecondary)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    TextField("8 or :30", text: Binding(
                        get: { log.reps.wrappedValue ?? "" },
                        set: { log.reps.wrappedValue = $0.isEmpty ? nil : $0 }
                    ))
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }

                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    Text("Weight (kg)")
                        .font(Theme.Font.cardSecondary)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    TextField("12", text: Binding(
                        get: { log.weight.wrappedValue ?? "" },
                        set: { log.weight.wrappedValue = $0.isEmpty ? nil : $0 }
                    ))
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }

            // Conditional Notes Field
            if showingNotes[logId] == true {
                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    Text("Notes")
                        .font(Theme.Font.cardSecondary)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    TextField("Assistance, progression notes", text: Binding(
                        get: { log.note.wrappedValue ?? "" },
                        set: { log.note.wrappedValue = $0.isEmpty ? nil : $0 }
                    ))
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func addLog() {
        logs.append(
            WorkoutLog(
                id: UUID().uuidString,
                exerciseId: "",
                exerciseName: "",
                isComplex: false,
                sets: nil,
                reps: "",
                weight: nil,
                note: nil
            )
        )
    }

    private func removeLog(_ id: String) {
        logs.removeAll { $0.id == id }
    }

    private func save() async {
        // Derive name from template or exercise names
        let workoutName: String?
        if let templateId = selectedTemplateId,
           let template = templates.first(where: { $0.id == templateId }) {
            workoutName = template.name
        } else {
            let names = logs.compactMap { $0.exerciseName.isEmpty ? nil : $0.exerciseName }
            workoutName = names.isEmpty ? nil : names.joined(separator: ", ")
        }

        try? await firestore.saveWorkout(
            id: workout?.id,
            name: workoutName,
            date: date,
            blockId: blockId,
            logs: logs
        )
    }

    private func mostRecentLog(exerciseId: String, isComplex: Bool) -> WorkoutLog? {
        // workouts are sorted by date descending, so first match = most recent
        for workout in workouts {
            if let log = workout.logs.first(where: {
                $0.exerciseId == exerciseId && $0.isComplex == isComplex
            }) {
                return log
            }
        }
        return nil
    }

    private func loadReferenceData() async {
        exercises = (try? await firestore.fetchExercises()) ?? []
        complexes = (try? await firestore.fetchComplexes()) ?? []
        blocks = (try? await firestore.fetchBlocks()) ?? []
        templates = (try? await firestore.fetchWorkoutTemplates()) ?? []
        workouts = (try? await firestore.fetchWorkouts()) ?? []

        if workout == nil, blockId == nil {

            blockId = blocks
                .filter { $0.completedDate == nil && $0.startDate <= Date() }
                .sorted { $0.startDate > $1.startDate }
                .first?.id
        }
    }
}
