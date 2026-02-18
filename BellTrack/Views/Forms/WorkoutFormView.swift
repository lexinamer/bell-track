import SwiftUI

struct WorkoutFormView: View {

    let workout: Workout?
    let onSave: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    @State private var blockId: String?
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var logs: [WorkoutLog]
    @State private var exercises: [Exercise] = []
    @State private var blocks: [Block] = []
    @State private var templates: [WorkoutTemplate] = []
    @State private var workouts: [Workout] = []

    private let firestore = FirestoreService.shared

    // MARK: - Init

    init(
        workout: Workout?,
        template: WorkoutTemplate? = nil,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.workout = workout
        self.onSave = onSave
        self.onCancel = onCancel
        _date = State(initialValue: workout?.date ?? Date())
        _blockId = State(initialValue: workout?.blockId ?? template?.blockId)
        _logs = State(initialValue: workout?.logs ?? [])
        _selectedTemplate = State(initialValue: template)
    }

    // MARK: - Derived

    private var isValid: Bool {
        !logs.isEmpty && logs.allSatisfy {
            guard let sets = $0.sets, sets > 0 else { return false }
            guard let reps = $0.reps, !reps.isEmpty else { return false }
            return true
        }
    }

    private var templateOptions: [(template: WorkoutTemplate, blockName: String)] {
        let activeBlocks = blocks.filter { $0.completedDate == nil && $0.startDate <= Date() }
        return templates.compactMap { template in
            guard let block = activeBlocks.first(where: { $0.id == template.blockId }) else { return nil }
            return (template, block.name)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brand.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Theme.Space.lg) {

                        // Header card
                        VStack(spacing: 0) {
                            // Template selector
                            if workout != nil {
                                HStack {
                                    Text("Template")
                                        .foregroundColor(Color.brand.textPrimary)
                                    Spacer()
                                    Text(selectedTemplate?.name ?? workout?.name ?? "Unknown")
                                        .foregroundColor(Color.brand.textSecondary)
                                }
                                .padding(.horizontal, Theme.Space.md)
                                .padding(.vertical, Theme.Space.smp)
                                .background(Color.brand.surface)
                            } else {
                                Menu {
                                    ForEach(templateOptions, id: \.template.id) { item in
                                        Button {
                                            selectedTemplate = item.template
                                            blockId = item.template.blockId
                                            loadTemplate(item.template)
                                        } label: {
                                            VStack(alignment: .leading) {
                                                Text(item.template.name)
                                                Text(item.blockName)
                                                    .font(.caption)
                                                    .foregroundColor(Color.brand.textSecondary)
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text("Template")
                                            .foregroundColor(Color.brand.textPrimary)
                                        Spacer()
                                        if let template = selectedTemplate {
                                            Text(template.name)
                                                .foregroundColor(Color.brand.textSecondary)
                                        } else {
                                            Text("Select...")
                                                .foregroundColor(Color.brand.primary)
                                        }
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(Color.brand.textSecondary)
                                    }
                                    .padding(.horizontal, Theme.Space.md)
                                    .padding(.vertical, Theme.Space.smp)
                                    .background(Color.brand.surface)
                                }
                            }
                            Divider().padding(.leading, Theme.Space.md)

                            // Date picker
                            HStack {
                                Text("Date")
                                    .foregroundColor(Color.brand.textPrimary)

                                Spacer()

                                DatePicker("", selection: $date, displayedComponents: .date)
                                    .labelsHidden()
                            }
                            .padding(.horizontal, Theme.Space.md)
                            .padding(.vertical, Theme.Space.smp)
                            .background(Color.brand.surface)
                        }
                        .cornerRadius(Theme.Radius.md)
                        .padding(.horizontal)

                        // Exercise cards
                        if !logs.isEmpty {
                            VStack(spacing: Theme.Space.md) {
                                ForEach($logs) { $log in
                                    exerciseCard(log: $log)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle(workout == nil ? "Log Workout" : "Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
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
                    .disabled(!isValid)
                }
            }
            .task {
                await loadReferenceData()
                if let template = selectedTemplate, logs.isEmpty {
                    loadTemplate(template)
                }
            }
        }
    }

    // MARK: - Exercise Card

    private func exerciseCard(log: Binding<WorkoutLog>) -> some View {
        let exercise = exercises.first(where: { $0.id == log.exerciseId.wrappedValue })
        let mode = exercise?.mode ?? .reps

        return VStack(spacing: Theme.Space.md) {

            HStack {
                Text(log.exerciseName.wrappedValue)
                    .font(Theme.Font.cardTitle)
                    .foregroundColor(Color.brand.textPrimary)
                Spacer()
            }

            inputField("Sets", placeholder: "5", value: log.sets, keyboard: .numberPad)

            inputField(
                mode == .reps ? "Reps" : "Time (sec)",
                placeholder: mode == .reps ? "8" : "30",
                text: Binding(
                    get: { log.reps.wrappedValue ?? "" },
                    set: { log.reps.wrappedValue = $0.isEmpty ? nil : $0 }
                ),
                keyboard: mode == .reps ? .numberPad : .decimalPad
            )

            inputField(
                "Weight (kg)",
                placeholder: "12",
                text: Binding(
                    get: { log.weight.wrappedValue ?? "" },
                    set: { log.weight.wrappedValue = $0.isEmpty ? nil : $0 }
                ),
                keyboard: .decimalPad
            )

            inputField(
                "Notes",
                placeholder: "e.g. felt heavy, adjust grip next time",
                text: Binding(
                    get: { log.note.wrappedValue ?? "" },
                    set: { log.note.wrappedValue = $0.isEmpty ? nil : $0 }
                ),
                keyboard: .default
            )
        }
        .padding(Theme.Space.md)
        .background(Color.brand.surface)
        .cornerRadius(Theme.Radius.md)
    }

    // MARK: - input helpers

    private func inputField(
        _ title: String,
        placeholder: String,
        value: Binding<Int?>,
        keyboard: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(title)
                .font(Theme.Font.cardSecondary)
                .foregroundColor(Color.brand.textSecondary)

            TextField(placeholder, value: value, format: .number)
                .keyboardType(keyboard)
                .padding(Theme.Space.sm)
                .background(Color.brand.background)
                .cornerRadius(Theme.Radius.sm)
        }
    }

    private func inputField(
        _ title: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(title)
                .font(Theme.Font.cardSecondary)
                .foregroundColor(Color.brand.textSecondary)

            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .padding(Theme.Space.sm)
                .background(Color.brand.background)
                .cornerRadius(Theme.Radius.sm)
        }
    }

    // MARK: - Data

    private func loadTemplate(_ template: WorkoutTemplate) {
        logs = template.entries.map {
            let recent = mostRecentLog(exerciseId: $0.exerciseId)
            return WorkoutLog(
                id: UUID().uuidString,
                exerciseId: $0.exerciseId,
                exerciseName: $0.exerciseName,
                sets: recent?.sets,
                reps: recent?.reps,
                weight: recent?.weight,
                isDouble: recent?.isDouble ?? false
            )
        }
    }

    private func save() async {
        try? await firestore.saveWorkout(
            id: workout?.id,
            name: selectedTemplate?.name ?? workout?.name,
            date: date,
            blockId: blockId,
            logs: logs
        )
    }

    private func mostRecentLog(exerciseId: String) -> WorkoutLog? {
        workouts.sorted(by: { $0.date > $1.date })
            .first { workout in
                workout.logs.contains { $0.exerciseId == exerciseId }
            }?
            .logs.first { $0.exerciseId == exerciseId }
    }

    private func loadReferenceData() async {
        exercises = (try? await firestore.fetchExercises()) ?? []
        blocks = (try? await firestore.fetchBlocks()) ?? []
        templates = (try? await firestore.fetchWorkoutTemplates()) ?? []
        workouts = (try? await firestore.fetchWorkouts()) ?? []

        if let workout = workout, let name = workout.name {
            selectedTemplate = templates.first { $0.name == name }
        }
    }
}
