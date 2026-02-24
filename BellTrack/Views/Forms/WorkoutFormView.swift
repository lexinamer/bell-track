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

    private var workoutType: WorkoutType {
        selectedTemplate?.workoutType ?? workout?.workoutType ?? .strict
    }

    private var isValid: Bool {
        switch workoutType {
        case .strict:
            return !logs.isEmpty
        case .timed:
            return selectedTemplate != nil && logs.contains { log in
                log.sets.contains { (Int($0.sets ?? 0) > 0) }
            }
        }
    }

    private var templateOptions: [(template: WorkoutTemplate, blockName: String)] {
        let today = Calendar.current.startOfDay(for: Date())
        let activeBlocks = blocks.filter {
            $0.completedDate == nil && Calendar.current.startOfDay(for: $0.startDate) <= today
        }
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

                        // Header card — date + template selector
                        VStack(spacing: 0) {
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

                            Divider().padding(.leading, Theme.Space.md)

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

                        switch workoutType {
                        case .strict:
                            strictBody
                        case .timed:
                            timedBody
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

    // MARK: - Strict Body

    private var strictBody: some View {
        VStack(spacing: Theme.Space.md) {
            ForEach($logs) { $log in
                strictExerciseCard(log: $log)
            }
        }
        .padding(.horizontal)
    }

    private func strictExerciseCard(log: Binding<WorkoutLog>) -> some View {
        let exerciseMode = exercises.first(where: { $0.id == log.wrappedValue.exerciseId })?.mode ?? .reps
        return VStack(alignment: .leading, spacing: Theme.Space.md) {

            Text(log.wrappedValue.exerciseName)
                .font(Theme.Font.cardTitle)
                .foregroundColor(Color.brand.textPrimary)

            HStack(spacing: Theme.Space.sm) {
                Text("Set")
                    .frame(width: 36, alignment: .leading)
                Text(exerciseMode == .time ? "Duration (sec)" : "Reps")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Weight (kg)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer().frame(width: 36)
                Spacer().frame(width: 28)
            }
            .font(Theme.Font.cardCaption)
            .foregroundColor(Color.brand.textSecondary)

            ForEach(Array(log.wrappedValue.sets.enumerated()), id: \.element.id) { index, _ in
                strictSetRow(
                    set: setBinding(log: log, index: index),
                    setNumber: index + 1,
                    canDelete: log.wrappedValue.sets.count > 1,
                    onDelete: {
                        var updated = log.wrappedValue
                        updated.sets.remove(at: index)
                        log.wrappedValue = updated
                    }
                )
            }

            Button {
                var updated = log.wrappedValue
                updated.addRow()
                log.wrappedValue = updated
            } label: {
                HStack(spacing: Theme.Space.xs) {
                    Image(systemName: "plus.circle")
                    Text("Add set")
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

    private func strictSetRow(set: Binding<LogSet>, setNumber: Int, canDelete: Bool, onDelete: @escaping () -> Void) -> some View {
        let isDouble = set.wrappedValue.isDouble
        let hasOffset = set.wrappedValue.offsetWeight != nil

        return HStack(spacing: Theme.Space.sm) {

            Text("\(setNumber)")
                .font(Theme.Font.cardCaption)
                .foregroundColor(Color.brand.textSecondary)
                .frame(width: 36, alignment: .leading)

            // Reps
            TextField("8", text: Binding(
                get: { set.wrappedValue.reps ?? "" },
                set: { set.wrappedValue.reps = $0.isEmpty ? nil : $0 }
            ))
            .keyboardType(.numberPad)
            .padding(.vertical, Theme.Space.sm)
            .padding(.horizontal, Theme.Space.sm)
            .background(Color.brand.background)
            .cornerRadius(Theme.Radius.sm)
            .frame(maxWidth: .infinity)

            // Weight — L when offset active
            TextField("12", text: Binding(
                get: { set.wrappedValue.weight ?? "" },
                set: { set.wrappedValue.weight = $0.isEmpty ? nil : $0 }
            ))
            .keyboardType(.decimalPad)
            .padding(.vertical, Theme.Space.sm)
            .padding(.horizontal, Theme.Space.sm)
            .background(Color.brand.background)
            .cornerRadius(Theme.Radius.sm)
            .frame(maxWidth: .infinity)

            // R (offset)
            if hasOffset {
                TextField("16", text: Binding(
                    get: { set.wrappedValue.offsetWeight ?? "" },
                    set: { set.wrappedValue.offsetWeight = $0.isEmpty ? nil : $0 }
                ))
                .keyboardType(.decimalPad)
                .padding(.vertical, Theme.Space.sm)
                .padding(.horizontal, Theme.Space.sm)
                .background(Color.brand.background)
                .cornerRadius(Theme.Radius.sm)
                .frame(maxWidth: .infinity)
            }

            // 2x / L/R cycle
            Button {
                if !isDouble && !hasOffset {
                    set.wrappedValue.isDouble = true
                } else if isDouble {
                    set.wrappedValue.isDouble = false
                    set.wrappedValue.offsetWeight = ""
                } else {
                    set.wrappedValue.offsetWeight = nil
                }
            } label: {
                Text(isDouble ? "2×" : (hasOffset ? "L/R" : "2×"))
                    .font(Theme.Font.cardCaption)
                    .foregroundColor((isDouble || hasOffset) ? .white : Color.brand.textSecondary)
                    .frame(width: 36)
                    .padding(.vertical, Theme.Space.sm)
                    .background((isDouble || hasOffset) ? Color.brand.primary : Color.brand.background)
                    .cornerRadius(Theme.Radius.sm)
            }
            .buttonStyle(.plain)

            Button { onDelete() } label: {
                Image(systemName: "minus.circle")
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(Color.brand.destructive)
            }
            .frame(width: 28)
            .opacity(canDelete ? 1 : 0)
            .disabled(!canDelete)
        }
    }

    // MARK: - Timed Body

    private var timedBody: some View {
        VStack(spacing: Theme.Space.md) {
            ForEach($logs) { $log in
                timedExerciseCard(log: $log)
            }
        }
        .padding(.horizontal)
    }

    private func timedExerciseCard(log: Binding<WorkoutLog>) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {

            Text(log.wrappedValue.exerciseName)
                .font(Theme.Font.cardTitle)
                .foregroundColor(Color.brand.textPrimary)

            HStack(spacing: Theme.Space.sm) {
                Text("Rounds")
                    .frame(width: 52, alignment: .leading)
                Text("Reps")
                    .frame(width: 52, alignment: .leading)
                Text("Weight (kg)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer().frame(width: 36)
                Spacer().frame(width: 28)
            }
            .font(Theme.Font.cardCaption)
            .foregroundColor(Color.brand.textSecondary)

            ForEach(Array(log.wrappedValue.sets.enumerated()), id: \.element.id) { index, _ in
                timedSetRow(log: log, index: index)
            }

            Button {
                var updated = log.wrappedValue
                updated.addRow()
                log.wrappedValue = updated
            } label: {
                HStack(spacing: Theme.Space.xs) {
                    Image(systemName: "plus.circle")
                    Text("Add row")
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

    private func timedSetRow(log: Binding<WorkoutLog>, index: Int) -> some View {
        let isDouble = log.wrappedValue.sets[safe: index]?.isDouble ?? false
        let hasOffset = log.wrappedValue.sets[safe: index]?.offsetWeight != nil
        let canDelete = log.wrappedValue.sets.count > 1

        return HStack(spacing: Theme.Space.sm) {

            // Rounds
            TextField("20", text: Binding(
                get: { log.wrappedValue.sets[safe: index]?.sets.map { "\($0)" } ?? "" },
                set: { val in
                    var updated = log.wrappedValue
                    if updated.sets.indices.contains(index) {
                        updated.sets[index].sets = Int(val)
                    }
                    log.wrappedValue = updated
                }
            ))
            .keyboardType(.numberPad)
            .padding(.vertical, Theme.Space.sm)
            .padding(.horizontal, Theme.Space.sm)
            .background(Color.brand.background)
            .cornerRadius(Theme.Radius.sm)
            .frame(width: 52)

            // Reps
            TextField("2", text: Binding(
                get: { log.wrappedValue.sets[safe: index]?.reps ?? "" },
                set: { val in
                    var updated = log.wrappedValue
                    if updated.sets.indices.contains(index) {
                        updated.sets[index].reps = val.isEmpty ? nil : val
                    }
                    log.wrappedValue = updated
                }
            ))
            .keyboardType(.numberPad)
            .padding(.vertical, Theme.Space.sm)
            .padding(.horizontal, Theme.Space.sm)
            .background(Color.brand.background)
            .cornerRadius(Theme.Radius.sm)
            .frame(width: 52)

            // Weight — L when offset active
            TextField("12", text: Binding(
                get: { log.wrappedValue.sets[safe: index]?.weight ?? "" },
                set: { val in
                    var updated = log.wrappedValue
                    if updated.sets.indices.contains(index) {
                        updated.sets[index].weight = val.isEmpty ? nil : val
                    }
                    log.wrappedValue = updated
                }
            ))
            .keyboardType(.decimalPad)
            .padding(.vertical, Theme.Space.sm)
            .padding(.horizontal, Theme.Space.sm)
            .background(Color.brand.background)
            .cornerRadius(Theme.Radius.sm)
            .frame(maxWidth: .infinity)

            // R (offset)
            if hasOffset {
                TextField("16", text: Binding(
                    get: { log.wrappedValue.sets[safe: index]?.offsetWeight ?? "" },
                    set: { val in
                        var updated = log.wrappedValue
                        if updated.sets.indices.contains(index) {
                            updated.sets[index].offsetWeight = val.isEmpty ? nil : val
                        }
                        log.wrappedValue = updated
                    }
                ))
                .keyboardType(.decimalPad)
                .padding(.vertical, Theme.Space.sm)
                .padding(.horizontal, Theme.Space.sm)
                .background(Color.brand.background)
                .cornerRadius(Theme.Radius.sm)
                .frame(maxWidth: .infinity)
            }

            // 2x / L/R cycle
            Button {
                var updated = log.wrappedValue
                if updated.sets.indices.contains(index) {
                    if !isDouble && !hasOffset {
                        updated.sets[index].isDouble = true
                    } else if isDouble {
                        updated.sets[index].isDouble = false
                        updated.sets[index].offsetWeight = ""
                    } else {
                        updated.sets[index].offsetWeight = nil
                    }
                }
                log.wrappedValue = updated
            } label: {
                Text(isDouble ? "2×" : (hasOffset ? "L/R" : "2×"))
                    .font(Theme.Font.cardCaption)
                    .foregroundColor((isDouble || hasOffset) ? .white : Color.brand.textSecondary)
                    .frame(width: 36)
                    .padding(.vertical, Theme.Space.sm)
                    .background((isDouble || hasOffset) ? Color.brand.primary : Color.brand.background)
                    .cornerRadius(Theme.Radius.sm)
            }
            .buttonStyle(.plain)

            Button {
                var updated = log.wrappedValue
                updated.sets.remove(at: index)
                log.wrappedValue = updated
            } label: {
                Image(systemName: "minus.circle")
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(Color.brand.destructive)
            }
            .frame(width: 28)
            .opacity(canDelete ? 1 : 0)
            .disabled(!canDelete)
        }
    }

    // MARK: - Helpers

    private func setBinding(log: Binding<WorkoutLog>, index: Int) -> Binding<LogSet> {
        Binding(
            get: { log.wrappedValue.sets[index] },
            set: { newValue in
                var updated = log.wrappedValue
                updated.sets[index] = newValue
                log.wrappedValue = updated
            }
        )
    }

    // MARK: - Data

    private func loadTemplate(_ template: WorkoutTemplate) {
        let recentWorkout = workouts
            .filter { $0.name == template.name }
            .sorted { $0.date > $1.date }
            .first

        logs = template.entries.map { entry in
            let recentSets = recentWorkout?
                .logs.first { $0.exerciseId == entry.exerciseId }?
                .sets
            return WorkoutLog(
                exerciseId: entry.exerciseId,
                exerciseName: entry.exerciseName,
                sets: recentSets ?? [LogSet()]
            )
        }
    }

    private func save() async {
        switch workoutType {
        case .strict:
            try? await firestore.saveWorkout(
                id: workout?.id,
                name: selectedTemplate?.name ?? workout?.name,
                date: date,
                blockId: blockId,
                logs: logs,
                workoutType: .strict
            )
        case .timed:
            guard let template = selectedTemplate else { return }
            try? await firestore.saveWorkout(
                id: workout?.id,
                name: template.name,
                date: date,
                blockId: blockId,
                logs: logs,
                workoutType: .timed
            )
        }
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

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
