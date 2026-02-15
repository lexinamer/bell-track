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
    @State private var showingTemplateSelector = false

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

    // MARK: - Derived

    private var isValid: Bool {
        // All logs must have valid values
        !logs.isEmpty && logs.allSatisfy { log in
            guard let sets = log.sets, sets > 0 else { return false }
            guard let reps = log.reps, !reps.isEmpty else { return false }
            guard let weight = log.weight, !weight.isEmpty else { return false }
            return true
        }
    }

    private var templateOptions: [(template: WorkoutTemplate, blockName: String)] {
        let activeBlocks = blocks.filter {
            $0.completedDate == nil && $0.startDate <= Date()
        }

        return templates.compactMap { template in
            guard let block = activeBlocks.first(where: { $0.id == template.blockId }) else {
                return nil
            }
            return (template, block.name)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brand.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Space.lg) {

                        // MARK: - Header Section

                        VStack(spacing: 0) {
                            // Template Name (if editing, show template name; if new, show selector)
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
                                Button {
                                    showingTemplateSelector = true
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
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color.brand.textSecondary)
                                    }
                                    .padding(.horizontal, Theme.Space.md)
                                    .padding(.vertical, Theme.Space.smp)
                                    .background(Color.brand.surface)
                                }
                            }

                            Divider()
                                .padding(.leading, Theme.Space.md)

                            // Date Picker
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

                        // MARK: - Exercises Section

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
            }
            .sheet(isPresented: $showingTemplateSelector) {
                TemplateSelector(
                    templates: templateOptions,
                    onSelect: { template in
                        selectedTemplate = template
                        blockId = template.blockId
                        loadTemplate(template)
                        showingTemplateSelector = false
                    },
                    onCancel: {
                        showingTemplateSelector = false
                    }
                )
            }
        }
    }

    // MARK: - Exercise Card

    private func exerciseCard(log: Binding<WorkoutLog>) -> some View {

        VStack(spacing: Theme.Space.md) {

            // Exercise name header
            HStack {
                Text(log.exerciseName.wrappedValue)
                    .font(Theme.Font.cardTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.brand.textPrimary)

                Spacer()
            }

            // Sets
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Text("Sets")
                    .font(Theme.Font.cardSecondary)
                    .fontWeight(.medium)
                    .foregroundColor(Color.brand.textSecondary)

                TextField("5", value: log.sets, format: .number)
                    .keyboardType(.numberPad)
                    .padding(Theme.Space.sm)
                    .background(Color.brand.background)
                    .foregroundColor(Color.brand.textPrimary)
                    .cornerRadius(Theme.Radius.sm)
            }

            // Reps or Time
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                HStack {
                    Text(log.mode.wrappedValue == .reps ? "Reps" : "Time (sec)")
                        .font(Theme.Font.cardSecondary)
                        .fontWeight(.medium)
                        .foregroundColor(Color.brand.textSecondary)

                    Spacer()

                    Button {
                        log.mode.wrappedValue = log.mode.wrappedValue == .reps ? .time : .reps
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 12))
                            Text(log.mode.wrappedValue == .reps ? "Switch to Time" : "Switch to Reps")
                                .font(Theme.Font.cardCaption)
                        }
                        .foregroundColor(Color.brand.primary)
                    }
                }

                TextField(log.mode.wrappedValue == .reps ? "8" : "30", text: Binding(
                    get: { log.reps.wrappedValue ?? "" },
                    set: { log.reps.wrappedValue = $0.isEmpty ? nil : $0 }
                ))
                .keyboardType(log.mode.wrappedValue == .reps ? .numberPad : .decimalPad)
                .padding(Theme.Space.sm)
                .background(Color.brand.background)
                .foregroundColor(Color.brand.textPrimary)
                .cornerRadius(Theme.Radius.sm)
            }

            // Weight with Double toggle
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                HStack {
                    Text("Weight (kg)")
                        .font(Theme.Font.cardSecondary)
                        .fontWeight(.medium)
                        .foregroundColor(Color.brand.textSecondary)

                    Spacer()

                    Toggle(isOn: log.isDouble) {
                        Text("Double")
                            .font(Theme.Font.cardCaption)
                            .foregroundColor(Color.brand.textSecondary)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: Color.brand.primary))
                }

                HStack(spacing: Theme.Space.sm) {
                    if log.isDouble.wrappedValue {
                        Text("2×")
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(Color.brand.textSecondary)
                    }

                    TextField("12", text: Binding(
                        get: { log.weight.wrappedValue ?? "" },
                        set: { log.weight.wrappedValue = $0.isEmpty ? nil : $0 }
                    ))
                    .keyboardType(.decimalPad)
                    .padding(Theme.Space.sm)
                    .background(Color.brand.background)
                    .foregroundColor(Color.brand.textPrimary)
                    .cornerRadius(Theme.Radius.sm)

                    Text("kg")
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(Color.brand.textSecondary)
                }
            }
        }
        .padding(Theme.Space.md)
        .background(Color.brand.surface)
        .cornerRadius(Theme.Radius.md)
    }

    // MARK: - Helpers

    private func loadTemplate(_ template: WorkoutTemplate) {
        logs = template.entries.map { entry in
            let recent = mostRecentLog(exerciseId: entry.exerciseId)

            return WorkoutLog(
                id: UUID().uuidString,
                exerciseId: entry.exerciseId,
                exerciseName: entry.exerciseName,
                mode: recent?.mode ?? .reps,
                sets: recent?.sets,
                reps: recent?.reps,
                weight: recent?.weight,
                isDouble: recent?.isDouble ?? false
            )
        }
    }

    private func save() async {
        let workoutName = selectedTemplate?.name ?? workout?.name

        try? await firestore.saveWorkout(
            id: workout?.id,
            name: workoutName,
            date: date,
            blockId: blockId,
            logs: logs
        )
    }

    private func mostRecentLog(exerciseId: String) -> WorkoutLog? {
        for workout in workouts.sorted(by: { $0.date > $1.date }) {
            if let log = workout.logs.first(where: {
                $0.exerciseId == exerciseId
            }) {
                return log
            }
        }
        return nil
    }

    private func loadReferenceData() async {
        exercises = (try? await firestore.fetchExercises()) ?? []
        blocks = (try? await firestore.fetchBlocks()) ?? []
        templates = (try? await firestore.fetchWorkoutTemplates()) ?? []
        workouts = (try? await firestore.fetchWorkouts()) ?? []

        // If editing, find and set template
        if let workout = workout, let workoutName = workout.name {
            selectedTemplate = templates.first { $0.name == workoutName }
            if selectedTemplate == nil {
                // Create a synthetic template from workout data
                selectedTemplate = WorkoutTemplate(
                    id: UUID().uuidString,
                    name: workoutName,
                    blockId: workout.blockId ?? "",
                    entries: workout.logs.map { log in
                        TemplateEntry(
                            exerciseId: log.exerciseId,
                            exerciseName: log.exerciseName
                        )
                    }
                )
            }
        }
    }
}
