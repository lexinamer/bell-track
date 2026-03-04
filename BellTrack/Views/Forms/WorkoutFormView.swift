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
    @State private var sharedRounds: String = ""
    @State private var sharedDuration: String = ""
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
        if let w = workout, w.workoutType == .amrap,
           let rounds = w.logs.first?.sets.first?.sets {
            _sharedRounds = State(initialValue: "\(rounds)")
        }
    }

    private var workoutType: WorkoutType {
        selectedTemplate?.workoutType ?? workout?.workoutType ?? .strict
    }

    private var isValid: Bool {
        switch workoutType {
        case .strict:
            return !logs.isEmpty
        case .amrap:
            return selectedTemplate != nil && !sharedRounds.isEmpty && Int(sharedRounds) != nil
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

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brand.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Theme.Space.lg) {
                        headerCard
                        switch workoutType {
                        case .strict: strictBody
                        case .amrap: amrapBody
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle(workout == nil ? "Log Workout" : "Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save(); onSave(); dismiss() }
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

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 0) {
            // Date row
            HStack {
                Text("Date").foregroundColor(Color.brand.textPrimary)
                Spacer()
                DatePicker("", selection: $date, displayedComponents: .date).labelsHidden()
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, Theme.Space.smp)
            .background(Color.brand.surface)

            Divider().padding(.leading, Theme.Space.md)

            // Template row
            if workout != nil {
                HStack {
                    Text("Template").foregroundColor(Color.brand.textPrimary)
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
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text(log.wrappedValue.exerciseName)
                .font(Theme.Font.cardTitle)
                .foregroundColor(Color.brand.textPrimary)

            HStack(spacing: Theme.Space.sm) {
                Text("Set").frame(width: 36, alignment: .leading)
                Text("Reps").frame(maxWidth: .infinity, alignment: .leading)
                Text("Weight").frame(maxWidth: .infinity, alignment: .leading)
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

            TextField("—", text: Binding(
                get: { set.wrappedValue.reps ?? "" },
                set: { set.wrappedValue.reps = $0.isEmpty ? nil : $0 }
            ))
            .keyboardType(.numberPad)
            .padding(.vertical, Theme.Space.sm)
            .padding(.horizontal, Theme.Space.sm)
            .background(Color.brand.background)
            .cornerRadius(Theme.Radius.sm)
            .frame(maxWidth: .infinity)

            HStack(spacing: Theme.Space.sm) {
                TextField(hasOffset ? "L" : "—", text: Binding(
                    get: { set.wrappedValue.weight ?? "" },
                    set: { set.wrappedValue.weight = $0.isEmpty ? nil : $0 }
                ))
                .keyboardType(.decimalPad)
                .padding(.vertical, Theme.Space.sm)
                .padding(.horizontal, Theme.Space.sm)
                .background(Color.brand.background)
                .cornerRadius(Theme.Radius.sm)
                .frame(maxWidth: .infinity)

                if hasOffset {
                    TextField("R", text: Binding(
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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

    // MARK: - AMRAP Body

    private var amrapBody: some View {
        VStack(spacing: Theme.Space.md) {

            // Rounds + Duration card
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                Text("Details")
                    .font(Theme.Font.cardTitle)
                    .foregroundColor(Color.brand.textPrimary)
                HStack(spacing: Theme.Space.sm) {
                    VStack(alignment: .leading, spacing: Theme.Space.xs) {
                        Text("Rounds")
                            .font(Theme.Font.cardCaption)
                            .foregroundColor(Color.brand.textSecondary)
                        TextField("0", text: $sharedRounds)
                            .keyboardType(.numberPad)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.brand.textPrimary)
                            .padding(.vertical, Theme.Space.sm)
                            .padding(.horizontal, Theme.Space.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.brand.background)
                            .cornerRadius(Theme.Radius.sm)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: Theme.Space.xs) {
                        Text("Duration (min)")
                            .font(Theme.Font.cardCaption)
                            .foregroundColor(Color.brand.textSecondary)
                        TextField("—", text: $sharedDuration)
                            .keyboardType(.numberPad)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.brand.textPrimary)
                            .padding(.vertical, Theme.Space.sm)
                            .padding(.horizontal, Theme.Space.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.brand.background)
                            .cornerRadius(Theme.Radius.sm)
                    }
                    .frame(maxWidth: .infinity)

                    // Spacer to match the 2× button width in exercise cards
                    Spacer().frame(width: 36)
                }
            }
            .padding(Theme.Space.md)
            .background(Color.brand.surface)
            .cornerRadius(Theme.Radius.md)
            .padding(.horizontal)

            ForEach($logs) { $log in
                amrapExerciseCard(log: $log)
            }
            .padding(.horizontal)
        }
    }

    private func amrapExerciseCard(log: Binding<WorkoutLog>) -> some View {
        let exerciseMode = exercises.first(where: { $0.id == log.wrappedValue.exerciseId })?.mode ?? .reps
        let repsHeader = exerciseMode == .time ? "Time (s)" : "Reps"
        let isDouble = log.wrappedValue.sets.first?.isDouble ?? false
        let hasOffset = log.wrappedValue.sets.first?.offsetWeight != nil

        return VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text(log.wrappedValue.exerciseName)
                .font(Theme.Font.cardTitle)
                .foregroundColor(Color.brand.textPrimary)

            // Column headers — mirrors strict layout
            HStack(spacing: Theme.Space.sm) {
                Text(repsHeader).frame(maxWidth: .infinity, alignment: .leading)
                Text("Weight").frame(maxWidth: .infinity, alignment: .leading)
                Spacer().frame(width: 36)
            }
            .font(Theme.Font.cardCaption)
            .foregroundColor(Color.brand.textSecondary)

            // Single data row: Reps | Weight | 2×
            HStack(spacing: Theme.Space.sm) {
                // Reps field
                TextField("—", text: Binding(
                    get: { log.wrappedValue.sets.first?.reps ?? "" },
                    set: { val in
                        var updated = log.wrappedValue
                        if updated.sets.isEmpty { updated.sets = [LogSet()] }
                        updated.sets[0].reps = val.isEmpty ? nil : val
                        log.wrappedValue = updated
                    }
                ))
                .keyboardType(.numberPad)
                .padding(.vertical, Theme.Space.sm)
                .padding(.horizontal, Theme.Space.sm)
                .background(Color.brand.background)
                .cornerRadius(Theme.Radius.sm)
                .frame(maxWidth: .infinity)

                // Weight field(s)
                HStack(spacing: Theme.Space.sm) {
                    TextField(hasOffset ? "L" : "—", text: Binding(
                        get: { log.wrappedValue.sets.first?.weight ?? "" },
                        set: { val in
                            var updated = log.wrappedValue
                            if updated.sets.isEmpty { updated.sets = [LogSet()] }
                            updated.sets[0].weight = val.isEmpty ? nil : val
                            log.wrappedValue = updated
                        }
                    ))
                    .keyboardType(.decimalPad)
                    .padding(.vertical, Theme.Space.sm)
                    .padding(.horizontal, Theme.Space.sm)
                    .background(Color.brand.background)
                    .cornerRadius(Theme.Radius.sm)
                    .frame(maxWidth: .infinity)

                    if hasOffset {
                        TextField("R", text: Binding(
                            get: { log.wrappedValue.sets.first?.offsetWeight ?? "" },
                            set: { val in
                                var updated = log.wrappedValue
                                if updated.sets.isEmpty { updated.sets = [LogSet()] }
                                updated.sets[0].offsetWeight = val.isEmpty ? nil : val
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
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 2× / L/R toggle
                Button {
                    var updated = log.wrappedValue
                    if updated.sets.isEmpty { updated.sets = [LogSet()] }
                    if !isDouble && !hasOffset {
                        updated.sets[0].isDouble = true
                    } else if isDouble {
                        updated.sets[0].isDouble = false
                        updated.sets[0].offsetWeight = ""
                    } else {
                        updated.sets[0].offsetWeight = nil
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
            }
        }
        .padding(Theme.Space.md)
        .background(Color.brand.surface)
        .cornerRadius(Theme.Radius.md)
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

        switch template.workoutType {
        case .strict:
            logs = template.entries.map { entry in
                let count = entry.defaultSets ?? 1
                let repsStr = entry.defaultReps
                // Always use template for set count and reps (so edits to the template are reflected).
                // Only carry forward the weight (and double/offset flags) from the most recent workout.
                let recentSetsForExercise = recentWorkout?.logs
                    .first(where: { $0.exerciseId == entry.exerciseId })?.sets ?? []
                let sets = (0..<count).map { i -> LogSet in
                    let recent = recentSetsForExercise[safe: i]
                    return LogSet(
                        reps: repsStr,
                        weight: recent?.weight,
                        isDouble: recent?.isDouble ?? false,
                        offsetWeight: recent?.offsetWeight
                    )
                }
                return WorkoutLog(exerciseId: entry.exerciseId, exerciseName: entry.exerciseName, sets: sets)
            }

        case .amrap:
            if let recent = recentWorkout, let rounds = recent.logs.first?.sets.first?.sets {
                sharedRounds = "\(rounds)"
            }
            if let duration = template.duration {
                sharedDuration = "\(duration)"
            }
            logs = template.entries.map { entry in
                let recent = recentWorkout?.logs.first(where: { $0.exerciseId == entry.exerciseId })?.sets.first
                let set = LogSet(
                    reps: recent?.reps ?? entry.defaultReps,
                    weight: recent?.weight,
                    isDouble: recent?.isDouble ?? false,
                    offsetWeight: recent?.offsetWeight
                )
                return WorkoutLog(exerciseId: entry.exerciseId, exerciseName: entry.exerciseName, sets: [set])
            }
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

        case .amrap:
            guard let template = selectedTemplate else { return }
            let rounds = Int(sharedRounds) ?? 0
            let savedLogs = logs.map { log -> WorkoutLog in
                var l = log
                if l.sets.isEmpty { l.sets = [LogSet()] }
                l.sets[0].sets = rounds
                // reps are already stored per-log; just stamp the round count
                return l
            }
            try? await firestore.saveWorkout(
                id: workout?.id,
                name: template.name,
                date: date,
                blockId: blockId,
                logs: savedLogs,
                workoutType: .amrap
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

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
