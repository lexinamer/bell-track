import SwiftUI
import FirebaseAuth

struct LogView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    private let firestoreService = FirestoreService()
    
    @State private var exercises: [Exercise] = []
    @State private var availableExercises: [String] = []
    @State private var workoutDate: Date = Date()
    
    var editingWorkout: Workout?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brand.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.Space.md) {
                        
                        // Date field
                        VStack(alignment: .leading, spacing: Theme.Space.xs) {
                            Text("Date")
                                .font(Theme.Font.meta)
                                .foregroundColor(Color.brand.textSecondary)
                            
                            DatePicker("", selection: $workoutDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, Theme.Space.md)
                        
                        // List of exercises
                        ForEach(exercises) { exercise in
                            SimpleExerciseRow(
                                exercise: Binding(
                                    get: { exercises.first(where: { $0.id == exercise.id }) ?? exercise },
                                    set: { newValue in
                                        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
                                            exercises[index] = newValue
                                        }
                                    }
                                ),
                                availableExercises: availableExercises,
                                onDelete: {
                                    exercises.removeAll { $0.id == exercise.id }
                                }
                            )
                        }
                        
                        // Add button
                        Button {
                            exercises.append(Exercise(
                                exerciseName: availableExercises.first ?? "",
                                rounds: nil,
                                reps: nil,
                                time: nil,
                                weightKg: nil,
                                isDoubleWeight: false,
                                note: nil
                            ))
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Exercise")
                            }
                            .font(Theme.Font.body)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.brand.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.brand.surface)
                            .cornerRadius(Theme.Radius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.md)
                                    .stroke(Color.brand.border, lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, Theme.Space.md)
                    }
                    .padding(.vertical, Theme.Space.md)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color.brand.textPrimary)
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Log Workout")
                        .font(Theme.Font.title)
                        .foregroundColor(Color.brand.textPrimary)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task { await saveWorkout() }
                    }
                    .foregroundColor(Color.brand.primary)
                    .disabled(exercises.isEmpty)
                }
            }
            .toolbarBackground(Color.brand.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task {
                await loadSettings()
                if let workout = editingWorkout {
                    exercises = workout.exercises
                    workoutDate = workout.date
                }
            }
        }
    }
    
    private func saveWorkout() async {
        guard let userId = authService.user?.uid else { return }
        
        let workout = Workout(
            id: editingWorkout?.id,
            userId: userId,
            date: workoutDate,
            exercises: exercises
        )
        
        do {
            try await firestoreService.saveWorkout(workout)
            dismiss()
        } catch {
            print("Error saving workout: \(error)")
        }
    }
    
    private func loadSettings() async {
        guard let userId = authService.user?.uid else { return }
        do {
            let settings = try await firestoreService.fetchSettings(userId: userId)
            availableExercises = settings.exercises
        } catch {
            print("Error loading settings: \(error)")
        }
    }
}

struct SimpleExerciseRow: View {
    @Binding var exercise: Exercise
    let availableExercises: [String]
    let onDelete: () -> Void
    
    @State private var useTime = false
    
    var body: some View {
        VStack(spacing: Theme.Space.md) {
            
            // Header with delete
            HStack {
                Text("Exercise")
                    .font(Theme.Font.meta)
                    .foregroundColor(Color.brand.textSecondary)
                
                Spacer()
                
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.brand.textSecondary)
                        .font(.system(size: 20))
                }
            }
            
            // Exercise picker
            Menu {
                ForEach(availableExercises, id: \.self) { ex in
                    Button(ex) {
                        exercise.exerciseName = ex
                    }
                }
            } label: {
                HStack {
                    Text(exercise.exerciseName)
                        .font(Theme.Font.body)
                        .foregroundColor(Color.brand.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(Color.brand.textSecondary)
                }
                .padding(.horizontal, Theme.Space.md)
                .padding(.vertical, Theme.Space.sm)
                .background(Color.brand.surface)
                .cornerRadius(Theme.Radius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .stroke(Color.brand.border, lineWidth: 1)
                )
            }
            
            // Rounds + Reps/Time
            HStack(spacing: Theme.Space.sm) {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text("Rounds")
                        .font(Theme.Font.meta)
                        .foregroundColor(Color.brand.textSecondary)
                    
                    TextField("4", value: $exercise.rounds, format: .number)
                        .keyboardType(.numberPad)
                        .font(Theme.Font.body)
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.vertical, Theme.Space.sm)
                        .background(Color.brand.surface)
                        .cornerRadius(Theme.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .stroke(Color.brand.border, lineWidth: 1)
                        )
                }
                
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    HStack(spacing: 4) {
                        Button("Reps") {
                            useTime = false
                            exercise.time = nil
                        }
                        .font(Theme.Font.meta)
                        .foregroundColor(useTime ? Color.brand.textSecondary : Color.brand.primary)
                        
                        Text("•")
                            .font(Theme.Font.meta)
                            .foregroundColor(Color.brand.textSecondary)
                        
                        Button("Time") {
                            useTime = true
                            exercise.reps = nil
                        }
                        .font(Theme.Font.meta)
                        .foregroundColor(useTime ? Color.brand.primary : Color.brand.textSecondary)
                    }
                    
                    if useTime {
                        TextField(":45", text: Binding(
                            get: { exercise.time ?? "" },
                            set: { exercise.time = $0.isEmpty ? nil : $0 }
                        ))
                        .font(Theme.Font.body)
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.vertical, Theme.Space.sm)
                        .background(Color.brand.surface)
                        .cornerRadius(Theme.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .stroke(Color.brand.border, lineWidth: 1)
                        )
                    } else {
                        TextField("8", value: $exercise.reps, format: .number)
                            .keyboardType(.numberPad)
                            .font(Theme.Font.body)
                            .padding(.horizontal, Theme.Space.md)
                            .padding(.vertical, Theme.Space.sm)
                            .background(Color.brand.surface)
                            .cornerRadius(Theme.Radius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.md)
                                    .stroke(Color.brand.border, lineWidth: 1)
                            )
                    }
                }
            }
            
            // Weight
            HStack(spacing: Theme.Space.sm) {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text("Weight (kg)")
                        .font(Theme.Font.meta)
                        .foregroundColor(Color.brand.textSecondary)
                    
                    TextField("12", value: $exercise.weightKg, format: .number)
                        .keyboardType(.decimalPad)
                        .font(Theme.Font.body)
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.vertical, Theme.Space.sm)
                        .background(Color.brand.surface)
                        .cornerRadius(Theme.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .stroke(Color.brand.border, lineWidth: 1)
                        )
                }
                
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text(" ")
                        .font(Theme.Font.meta)
                    
                    Button {
                        exercise.isDoubleWeight.toggle()
                    } label: {
                        Text("Doubles")
                            .font(Theme.Font.body)
                            .foregroundColor(Color.brand.textPrimary)
                            .padding(.horizontal, Theme.Space.md)
                            .padding(.vertical, Theme.Space.sm)
                            .background(Color.brand.surface)
                            .cornerRadius(Theme.Radius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.md)
                                    .stroke(exercise.isDoubleWeight ? Color.brand.primary : Color.brand.border, lineWidth: exercise.isDoubleWeight ? 2 : 1)
                            )
                    }
                }
            }
            
            // Note
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text("Note")
                    .font(Theme.Font.meta)
                    .foregroundColor(Color.brand.textSecondary)
                
                TextField("Optional", text: Binding(
                    get: { exercise.note ?? "" },
                    set: { exercise.note = $0.isEmpty ? nil : $0 }
                ))
                .font(Theme.Font.body)
                .padding(.horizontal, Theme.Space.md)
                .padding(.vertical, Theme.Space.sm)
                .background(Color.brand.surface)
                .cornerRadius(Theme.Radius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .stroke(Color.brand.border, lineWidth: 1)
                )
            }
        }
        .padding(Theme.Space.md)
        .background(Color.brand.surface)
        .cornerRadius(Theme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Color.brand.border, lineWidth: 1)
        )
        .padding(.horizontal, Theme.Space.md)
        .onAppear {
            useTime = exercise.time != nil
        }
    }
}
