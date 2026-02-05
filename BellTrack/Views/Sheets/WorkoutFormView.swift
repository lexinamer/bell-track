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
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // MARK: - Exercises Section
                    VStack(spacing: 20) {
                        ForEach($logs) { $log in
                            exerciseCard(log: $log)
                        }

                        Button(action: addLog) {
                            HStack(spacing: 8) {
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
        VStack(spacing: 16) {
            
            // Exercise Selection with Delete Button
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Exercise")
                        .font(Theme.Font.cardSecondary)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Note icon
                    Button {
                        showingNotes[log.wrappedValue.id] = !(showingNotes[log.wrappedValue.id] ?? false)
                    } label: {
                        Image(systemName: log.wrappedValue.note?.isEmpty == false ? "note.text" : "note")
                            .foregroundColor(log.wrappedValue.note?.isEmpty == false ? .blue : .gray)
                            .font(Theme.Font.cardSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button {
                        removeLog(log.wrappedValue.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(Theme.Font.cardTitle)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Menu {
                    ForEach(exercises) { exercise in
                        Button(exercise.name) {
                            log.exerciseId.wrappedValue = exercise.id
                            log.exerciseName.wrappedValue = exercise.name
                        }
                    }
                } label: {
                    HStack {
                        Text(
                            log.exerciseName.wrappedValue.isEmpty
                            ? "Select exercise"
                            : log.exerciseName.wrappedValue
                        )
                        .foregroundColor(log.exerciseName.wrappedValue.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                            .font(Theme.Font.cardCaption)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Single row layout: Rounds | Reps/Time | Weight
            HStack(spacing: 12) {
                // Rounds (now called Sets for consistency)
                VStack(alignment: .leading, spacing: 8) {
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
                
                // Reps (simplified)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reps or Time")
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
                
                // Weight (String)
                VStack(alignment: .leading, spacing: 8) {
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
            
            // Conditional Notes Field (only show when note icon is tapped)
            if showingNotes[log.wrappedValue.id] == true {
                VStack(alignment: .leading, spacing: 8) {
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
                sets: nil,
                reps: "", // Initialize as empty string, not nil
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
            date: date,
            blockId: blockId,
            logs: logs
        )
    }

    private func loadReferenceData() async {
        exercises = (try? await firestore.fetchExercises()) ?? []
        blocks = (try? await firestore.fetchBlocks()) ?? []
    }
}
