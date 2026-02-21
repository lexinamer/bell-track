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
        !logs.isEmpty && logs.allSatisfy { !$0.sets.isEmpty }
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

                            // Date row
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

                            // Template row
                            if workout != nil {
                                Divider().padding(.leading, Theme.Space.md)
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
                                Divider().padding(.leading, Theme.Space.md)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: Theme.Space.sm) {
                                        ForEach(templateOptions, id: \.template.id) { item in
                                            let isSelected = selectedTemplate?.id == item.template.id
                                            Button {
                                                selectedTemplate = item.template
                                                blockId = item.template.blockId
                                                loadTemplate(item.template)
                                            } label: {
                                                Text(item.template.name)
                                                    .font(Theme.Font.cardCaption)
                                                    .foregroundColor(isSelected ? .white : Color.brand.textPrimary)
                                                    .padding(.horizontal, Theme.Space.md)
                                                    .padding(.vertical, Theme.Space.smp)
                                                    .background(isSelected ? Color.brand.primary : Color.brand.background)
                                                    .clipShape(Capsule())
                                                    .overlay(Capsule().stroke(isSelected ? Color.clear : Color.brand.textSecondary.opacity(0.3), lineWidth: 1))
                                            }
                                        }
                                    }
                                    .padding(.horizontal, Theme.Space.md)
                                    .padding(.vertical, Theme.Space.smp)
                                }
                                .background(Color.brand.surface)
                            }
                        }
                        .cornerRadius(Theme.Radius.md)
                        .padding(.horizontal)

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
        let exercise = exercises.first(where: { $0.id == log.wrappedValue.exerciseId })
        let mode = exercise?.mode ?? .reps

        return VStack(alignment: .leading, spacing: Theme.Space.md) {

            Text(log.wrappedValue.exerciseName)
                .font(Theme.Font.cardTitle)
                .foregroundColor(Color.brand.textPrimary)

            ForEach(Array(log.wrappedValue.sets.enumerated()), id: \.element.id) { index, _ in

                let setBinding = Binding<LogSet>(
                    get: { log.wrappedValue.sets[index] },
                    set: { newValue in
                        var updated = log.wrappedValue
                        updated.sets[index] = newValue
                        log.wrappedValue = updated
                    }
                )

                setGroup(
                    set: setBinding,
                    mode: mode,
                    index: index,
                    showDelete: index > 0,
                    onDelete: {
                        var updated = log.wrappedValue
                        updated.sets.remove(at: index)
                        log.wrappedValue = updated
                    }
                )
            }

            Button {
                var updated = log.wrappedValue
                let last = updated.sets.last ?? LogSet()
                updated.sets.append(
                    LogSet(
                        sets: last.sets,
                        reps: last.reps,
                        weight: last.weight,
                        isDouble: last.isDouble
                    )
                )
                log.wrappedValue = updated
            } label: {
                HStack(spacing: Theme.Space.xs) {
                    Image(systemName: "plus.circle")
                    Text("Add set group")
                }
                .font(Theme.Font.cardCaption)
                .foregroundColor(Color.brand.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Space.md)
        .background(Color.brand.surface)
        .cornerRadius(Theme.Radius.md)
    }

    // MARK: - Rows

    private func setRowHeader(mode: ExerciseMode) -> some View {
        EmptyView()
    }

    private func setGroup(set: Binding<LogSet>, mode: ExerciseMode, index: Int, showDelete: Bool, onDelete: @escaping () -> Void) -> some View {
        let isOffset = set.wrappedValue.offsetWeight != nil

        return VStack(alignment: .leading, spacing: Theme.Space.sm) {

            // Divider between set groups (not before the first)
            if index > 0 {
                Divider()
                    .overlay(Color.brand.textSecondary.opacity(0.3))
                    .padding(.vertical, Theme.Space.sm)
            }

            // Row 1: Sets + delete button
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text("Sets")
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(Color.brand.textSecondary)
                HStack(spacing: Theme.Space.sm) {
                    TextField("5", text: Binding(
                        get: {
                            if let s = set.wrappedValue.sets, s > 0 { return "\(s)" }
                            return ""
                        },
                        set: { set.wrappedValue.sets = Int($0) }
                    ))
                    .keyboardType(.numberPad)
                    .padding(.vertical, Theme.Space.md)
                    .padding(.horizontal, Theme.Space.sm)
                    .background(Color.brand.background)
                    .cornerRadius(Theme.Radius.sm)
                    .frame(maxWidth: .infinity)

                    if showDelete {
                        Button(action: onDelete) {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color.brand.destructive)
                        }
                    }
                }
            }

            // Row 2: Reps
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(mode == .reps ? "Reps" : "Sec")
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(Color.brand.textSecondary)
                TextField(mode == .reps ? "5" : "30", text: Binding(
                    get: { set.wrappedValue.reps ?? "" },
                    set: { set.wrappedValue.reps = $0.isEmpty ? nil : $0 }
                ))
                .keyboardType(.numberPad)
                .padding(.vertical, Theme.Space.md)
                .padding(.horizontal, Theme.Space.sm)
                .background(Color.brand.background)
                .cornerRadius(Theme.Radius.sm)
                .frame(maxWidth: .infinity)
            }

            // Row 3: Weight + inline chips
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text("Weight")
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(Color.brand.textSecondary)
                HStack(spacing: Theme.Space.sm) {
                    TextField("0", text: Binding(
                        get: { set.wrappedValue.weight ?? "" },
                        set: { set.wrappedValue.weight = $0.isEmpty ? nil : $0 }
                    ))
                    .keyboardType(.decimalPad)
                    .padding(.vertical, Theme.Space.md)
                    .padding(.horizontal, Theme.Space.sm)
                    .background(Color.brand.background)
                    .cornerRadius(Theme.Radius.sm)
                    .frame(maxWidth: .infinity)

                    // Offset weight field — only when offset active
                    if isOffset {
                        TextField("offset", text: Binding(
                            get: { set.wrappedValue.offsetWeight ?? "" },
                            set: { set.wrappedValue.offsetWeight = $0.isEmpty ? nil : $0 }
                        ))
                        .keyboardType(.decimalPad)
                        .padding(.vertical, Theme.Space.md)
                        .padding(.horizontal, Theme.Space.sm)
                        .background(Color.brand.background)
                        .cornerRadius(Theme.Radius.sm)
                        .frame(maxWidth: .infinity)
                    }

                    // 2x chip
                    Button {
                        set.wrappedValue.isDouble = !set.wrappedValue.isDouble
                    } label: {
                        Text("2x")
                            .font(Theme.Font.cardCaption)
                            .foregroundColor(set.wrappedValue.isDouble ? .white : Color.brand.textSecondary)
                            .frame(width: 56)
                            .frame(maxHeight: .infinity)
                            .background(set.wrappedValue.isDouble ? Color.brand.primary : Color.brand.background)
                            .cornerRadius(Theme.Radius.sm)
                    }
                    .disabled(isOffset)
                    .opacity(isOffset ? 0.3 : 1)

                    // Offset chip
                    Button {
                        if isOffset {
                            set.wrappedValue.offsetWeight = nil
                        } else {
                            set.wrappedValue.offsetWeight = ""
                        }
                    } label: {
                        Text("Offset")
                            .font(Theme.Font.cardCaption)
                            .foregroundColor(isOffset ? .white : Color.brand.textSecondary)
                            .frame(width: 56)
                            .frame(maxHeight: .infinity)
                            .background(isOffset ? Color.brand.primary : Color.brand.background)
                            .cornerRadius(Theme.Radius.sm)
                    }
                    .disabled(set.wrappedValue.isDouble)
                    .opacity(set.wrappedValue.isDouble ? 0.3 : 1)
                }
            }
        }
    }

    // MARK: - Input helper

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
        logs = template.entries.map { entry in
            let recent = mostRecentLog(exerciseId: entry.exerciseId)
            let sets = recent?.sets ?? [LogSet()]
            return WorkoutLog(
                exerciseId: entry.exerciseId,
                exerciseName: entry.exerciseName,
                sets: sets
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
