import SwiftUI

struct WorkoutTemplateFormView: View {

    let template: WorkoutTemplate?
    let exercises: [Exercise]
    let onSave: (String, [TemplateEntry], WorkoutType, Int?) -> Void
    let onDelete: (() -> Void)?
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var nameInput: String
    @State private var selectedEntries: [TemplateEntry]
    @State private var workoutType: WorkoutType
    @State private var durationMinutes: String
    @State private var showingDeleteAlert = false

    init(
        template: WorkoutTemplate? = nil,
        exercises: [Exercise],
        onSave: @escaping (String, [TemplateEntry], WorkoutType, Int?) -> Void,
        onDelete: (() -> Void)? = nil,
        onCancel: @escaping () -> Void
    ) {
        self.template = template
        self.exercises = exercises
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _nameInput = State(initialValue: template?.name ?? "")
        _selectedEntries = State(initialValue: template?.entries ?? [])
        _workoutType = State(initialValue: template?.workoutType ?? .strict)
        _durationMinutes = State(initialValue: template?.duration.map { "\($0)" } ?? "30")
    }

    private var canSave: Bool {
        !nameInput.trimmingCharacters(in: .whitespaces).isEmpty && !selectedEntries.isEmpty
    }

    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {
                    headerCard
                    if !selectedEntries.isEmpty { exercisesCard }
                    addExerciseList
                    if template != nil && onDelete != nil { deleteButton }
                }
                .padding(.vertical, Theme.Space.md)
            }
        }
        .navigationTitle(template == nil ? "New Template" : "Edit Template")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let duration = workoutType == .amrap ? Int(durationMinutes) : nil
                    onSave(nameInput.trimmingCharacters(in: .whitespaces), selectedEntries, workoutType, duration)
                    // No dismiss() here — parent controls navigation via binding
                }
                .disabled(!canSave)
            }
        }
        .alert("Delete Template?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete?(); dismiss() }
        } message: {
            Text("This will permanently delete \"\(template?.name ?? "")\".")
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text("Name")
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(Color.brand.textSecondary)
                TextField("e.g. Workout A", text: $nameInput)
                    .autocorrectionDisabled()
                    .padding(.vertical, Theme.Space.md)
                    .padding(.horizontal, Theme.Space.sm)
                    .background(Color.brand.background)
                    .cornerRadius(Theme.Radius.sm)
            }
            .padding(Theme.Space.md)

            Divider().padding(.leading, Theme.Space.md)

            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text("Type")
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(Color.brand.textSecondary)
                HStack(spacing: Theme.Space.sm) {
                    ForEach([WorkoutType.strict, .amrap], id: \.self) { type in
                        Button { workoutType = type } label: {
                            Text(type.displayName)
                                .font(Theme.Font.cardCaption)
                                .foregroundColor(workoutType == type ? .white : Color.brand.textPrimary)
                                .padding(.horizontal, Theme.Space.md)
                                .padding(.vertical, Theme.Space.smp)
                                .background(workoutType == type ? Color.brand.primary : Color.brand.background)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(workoutType == type ? Color.clear : Color.brand.textSecondary.opacity(0.3), lineWidth: 1))
                        }
                    }
                }
            }
            .padding(Theme.Space.md)

            if workoutType == .amrap {
                Divider().padding(.leading, Theme.Space.md)
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text("Duration (minutes)")
                        .font(Theme.Font.cardCaption)
                        .foregroundColor(Color.brand.textSecondary)
                    TextField("30", text: $durationMinutes)
                        .keyboardType(.numberPad)
                        .padding(.vertical, Theme.Space.md)
                        .padding(.horizontal, Theme.Space.sm)
                        .background(Color.brand.background)
                        .cornerRadius(Theme.Radius.sm)
                }
                .padding(Theme.Space.md)
            }
        }
        .background(Color.brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .padding(.horizontal, Theme.Space.md)
    }

    // MARK: - Exercises Card

    private var exercisesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Exercises")
                .font(Theme.Font.cardCaption)
                .foregroundColor(Color.brand.textSecondary)
                .padding(.horizontal, Theme.Space.md)
                .padding(.bottom, Theme.Space.xs)

            VStack(spacing: 0) {
                ForEach(Array(selectedEntries.enumerated()), id: \.element.id) { index, _ in
                    entryRow(index: index)
                    if index < selectedEntries.count - 1 {
                        Divider().padding(.leading, Theme.Space.md)
                    }
                }
            }
            .background(Color.brand.surface)
            .cornerRadius(Theme.Radius.md)
            .padding(.horizontal, Theme.Space.md)
        }
    }

    // MARK: - Add Exercise List

    private var addExerciseList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Add Exercise")
                .font(Theme.Font.cardCaption)
                .foregroundColor(Color.brand.textSecondary)
                .padding(.horizontal, Theme.Space.md)
                .padding(.bottom, Theme.Space.xs)

            VStack(spacing: 0) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                    let isAdded = selectedEntries.contains { $0.exerciseId == exercise.id }
                    Button {
                        if !isAdded {
                            selectedEntries.append(TemplateEntry(
                                exerciseId: exercise.id,
                                exerciseName: exercise.name
                            ))
                        }
                    } label: {
                        HStack {
                            Text(exercise.name)
                                .font(Theme.Font.cardSecondary)
                                .foregroundColor(isAdded ? Color.brand.textSecondary : Color.brand.textPrimary)
                            Spacer()
                            Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                                .foregroundColor(isAdded ? Color.brand.textSecondary : Color.brand.primary)
                        }
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.vertical, Theme.Space.md)
                        .background(Color.brand.surface)
                    }
                    .disabled(isAdded)

                    if index < exercises.count - 1 {
                        Divider().padding(.leading, Theme.Space.md)
                    }
                }
            }
            .cornerRadius(Theme.Radius.md)
            .padding(.horizontal, Theme.Space.md)
        }
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button(role: .destructive) {
            showingDeleteAlert = true
        } label: {
            Label("Delete Template", systemImage: "trash")
                .foregroundStyle(Color.brand.destructive)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Theme.Space.md)
    }

    // MARK: - Entry Row

    @ViewBuilder
    private func entryRow(index: Int) -> some View {
        HStack(spacing: Theme.Space.sm) {
            Text(selectedEntries[index].exerciseName)
                .font(Theme.Font.cardSecondary)
                .foregroundColor(Color.brand.textPrimary)

            Spacer()

            if workoutType == .strict {
                Text("Sets")
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(Color.brand.textSecondary)
                TextField("—", text: Binding(
                    get: { selectedEntries[index].defaultSets.map { "\($0)" } ?? "" },
                    set: { selectedEntries[index].defaultSets = $0.isEmpty ? nil : Int($0) }
                ))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .padding(.vertical, Theme.Space.sm)
                .padding(.horizontal, Theme.Space.sm)
                .background(Color.brand.background)
                .cornerRadius(Theme.Radius.sm)
                .frame(width: 44)
            }

            Text("Reps")
                .font(Theme.Font.cardCaption)
                .foregroundColor(Color.brand.textSecondary)
            TextField("—", text: Binding(
                get: { selectedEntries[index].defaultReps ?? "" },
                set: { selectedEntries[index].defaultReps = $0.isEmpty ? nil : $0 }
            ))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .padding(.vertical, Theme.Space.sm)
            .padding(.horizontal, Theme.Space.sm)
            .background(Color.brand.background)
            .cornerRadius(Theme.Radius.sm)
            .frame(width: 44)

            Button {
                selectedEntries.remove(at: index)
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundColor(Color.brand.destructive)
            }
            .padding(.leading, Theme.Space.xs)
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.vertical, Theme.Space.md)
    }
}
