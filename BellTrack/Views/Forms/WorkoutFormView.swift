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
        // All logs must have valid sets and reps (weight is optional)
        !logs.isEmpty && logs.allSatisfy { log in
            guard let sets = log.sets, sets > 0 else { return false }
            guard let reps = log.reps, !reps.isEmpty else { return false }
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
                // If a template was passed in via init, load it after reference data is loaded
                if let template = selectedTemplate, logs.isEmpty {
                    loadTemplate(template)
                }
            }
            .sheet(isPresented: $showingTemplateSelector) {
                TemplateSelectorSheet(
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
        let exercise = exercises.first(where: { $0.id == log.exerciseId.wrappedValue })
        let mode = exercise?.mode ?? .reps

        return VStack(spacing: Theme.Space.md) {

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
                Text(mode == .reps ? "Reps" : "Time (sec)")
                    .font(Theme.Font.cardSecondary)
                    .fontWeight(.medium)
                    .foregroundColor(Color.brand.textSecondary)

                TextField(mode == .reps ? "8" : "30", text: Binding(
                    get: { log.reps.wrappedValue ?? "" },
                    set: { log.reps.wrappedValue = $0.isEmpty ? nil : $0 }
                ))
                .keyboardType(mode == .reps ? .numberPad : .decimalPad)
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

                    Button {
                        log.isDouble.wrappedValue.toggle()
                    } label: {
                        Text("Doubles")
                            .font(Theme.Font.cardCaption)
                            .padding(.horizontal, Theme.Space.sm)
                            .padding(.vertical, 4)
                            .background(log.isDouble.wrappedValue ? Color.brand.primary.opacity(0.15) : Color(.systemGray5))
                            .foregroundColor(log.isDouble.wrappedValue ? Color.brand.primary : Color.brand.textSecondary)
                            .cornerRadius(12)
                    }
                }

                HStack(spacing: 4) {
                    if log.isDouble.wrappedValue {
                        Text("2×")
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(Color.brand.textPrimary)
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
                }
            }

            // Notes (optional)
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Text("Notes")
                    .font(Theme.Font.cardSecondary)
                    .fontWeight(.medium)
                    .foregroundColor(Color.brand.textSecondary)

                TextField("Medium band, pause at top, etc.", text: Binding(
                    get: { log.note.wrappedValue ?? "" },
                    set: { log.note.wrappedValue = $0.isEmpty ? nil : $0 }
                ))
                .padding(Theme.Space.sm)
                .background(Color.brand.background)
                .foregroundColor(Color.brand.textPrimary)
                .cornerRadius(Theme.Radius.sm)
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

        // If editing, try to match template by name
        if let workout = workout, let workoutName = workout.name {
            selectedTemplate = templates.first { $0.name == workoutName }
        }
    }
}

// MARK: - Template Selector Sheet

private struct TemplateSelectorSheet: View {

    let templates: [(template: WorkoutTemplate, blockName: String)]
    let onSelect: (WorkoutTemplate) -> Void
    let onCancel: () -> Void

    var body: some View {

        NavigationStack {
            ZStack {
                Color.brand.background
                    .ignoresSafeArea()

                if templates.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(templates, id: \.template.id) { item in
                            Button {
                                onSelect(item.template)
                            } label: {
                                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                                    Text(item.template.name)
                                        .font(Theme.Font.cardTitle)
                                        .foregroundColor(Color.brand.textPrimary)

                                    Text(item.blockName)
                                        .font(Theme.Font.cardCaption)
                                        .foregroundColor(Color.brand.textSecondary)
                                }
                                .padding(.vertical, Theme.Space.xs)
                            }
                            .listRowBackground(Color.brand.surface)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Select Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Space.md) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 44))
                .foregroundColor(Color.brand.textSecondary)

            Text("No templates available")
                .font(Theme.Font.emptyStateTitle)
                .foregroundColor(Color.brand.textPrimary)

            Text("Create templates in your active blocks first.")
                .font(Theme.Font.emptyStateDescription)
                .foregroundColor(Color.brand.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Space.xl)
        }
    }
}
