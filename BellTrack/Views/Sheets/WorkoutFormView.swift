import SwiftUI

struct WorkoutFormView: View {

    let workout: Workout?
    let onSave: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var date: Date
    @State private var blockId: String?
    @State private var logs: [WorkoutLog]
    @State private var exercises: [Exercise] = []
    @State private var complexes: [Complex] = []
    @State private var blocks: [Block] = []
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

        _name = State(initialValue: workout?.name ?? "")
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
                        // Name
                        HStack {
                            Text("Name")
                            Spacer()
                            TextField("e.g. Workout A, Upper Body", text: $name)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))

                        Divider()
                            .padding(.leading, 16)

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
                                    Text("None")
                                        .tag(String?.none)
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
                    .disabled(logs.isEmpty)
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

            // Header: selected name + action icons
            HStack {
                Text(log.exerciseName.wrappedValue.isEmpty ? "Select exercise" : log.exerciseName.wrappedValue)
                    .font(Theme.Font.cardTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(log.exerciseName.wrappedValue.isEmpty ? .gray : .primary)
                    .lineLimit(1)

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

            // Exercise / Complex chips (single row)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.sm) {
                    // Complex chips first (with icon)
                    if !complexes.isEmpty {
                        ForEach(complexes) { complex in
                            exerciseChip(
                                title: complex.name,
                                isSelected: log.exerciseId.wrappedValue == complex.id && log.isComplex.wrappedValue,
                                isComplex: true
                            ) {
                                log.exerciseId.wrappedValue = complex.id
                                log.exerciseName.wrappedValue = complex.name
                                log.isComplex.wrappedValue = true
                            }
                        }
                    }

                    // Exercise chips
                    ForEach(exercises) { exercise in
                        exerciseChip(
                            title: exercise.name,
                            isSelected: log.exerciseId.wrappedValue == exercise.id && !log.isComplex.wrappedValue
                        ) {
                            log.exerciseId.wrappedValue = exercise.id
                            log.exerciseName.wrappedValue = exercise.name
                            log.isComplex.wrappedValue = false
                        }
                    }
                }
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

    // MARK: - Exercise Chip

    private func exerciseChip(
        title: String,
        isSelected: Bool,
        isComplex: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isComplex {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 12))
                }
                Text(title)
            }
            .font(Theme.Font.cardSecondary)
            .lineLimit(1)
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, Theme.Space.sm)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        isSelected
                            ? Color.brand.primary.opacity(0.15)
                            : Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? Color.clear : Color(.systemGray4),
                        lineWidth: 1
                    )
            )
            .foregroundColor(
                isSelected ? Color.brand.primary : .primary
            )
        }
        .buttonStyle(PlainButtonStyle())
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
        try? await firestore.saveWorkout(
            id: workout?.id,
            name: name.isEmpty ? nil : name,
            date: date,
            blockId: blockId,
            logs: logs
        )
    }

    private func loadReferenceData() async {
        exercises = (try? await firestore.fetchExercises()) ?? []
        complexes = (try? await firestore.fetchComplexes()) ?? []
        blocks = (try? await firestore.fetchBlocks()) ?? []
    }
}
