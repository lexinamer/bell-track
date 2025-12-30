import SwiftUI
import FirebaseAuth

struct AddEditBlockView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @State private var date = Date()
    @State private var formExercises: [FormExercise] = [FormExercise(name: "", repsText: "")]
    @State private var roundsText = ""
    @State private var selectedType: WorkoutBlock.BlockType = .sets
    @State private var selectedStyle: WorkoutBlock.BlockStyle = .single
    @State private var weightText = ""
    @State private var isSaving = false
    @State private var showDatePicker = false
    private let firestoreService = FirestoreService()
    
    let existingBlock: WorkoutBlock?
    let isEditing: Bool
    
    init(existingBlock: WorkoutBlock? = nil, isEditing: Bool = false) {
        self.existingBlock = existingBlock
        self.isEditing = isEditing
    }
    
    struct FormExercise: Identifiable {
        var id = UUID()
        var name: String
        var repsText: String
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    // Date
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Date")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.brand.textPrimary)
                        
                        Button(action: { showDatePicker = true }) {
                            HStack {
                                Text(date.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundColor(Color.brand.textPrimary)
                                Spacer()
                                Image(systemName: "calendar")
                                    .foregroundColor(Color.brand.textSecondary)
                            }
                            .padding(Spacing.md)
                            .background(Color.brand.surface)
                            .cornerRadius(CornerRadius.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.sm)
                                    .stroke(Color.brand.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Exercises
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        ForEach(formExercises.indices, id: \.self) { index in
                            HStack(alignment: .center, spacing: Spacing.sm) {
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    if index == 0 {
                                        Text("Exercise")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color.brand.textPrimary)
                                    }
                                    TextField("Exercise name", text: $formExercises[index].name)
                                        .customTextField()
                                }
                                
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    if index == 0 {
                                        Text("Reps")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color.brand.textPrimary)
                                    }
                                    TextField("Reps", text: $formExercises[index].repsText)
                                        .keyboardType(.numberPad)
                                        .frame(width: 80)
                                        .customTextField()
                                }
                                
                                VStack {
                                    if index == 0 {
                                        Spacer()
                                            .frame(height: 28)
                                    }
                                    Button(action: {
                                        if formExercises.count > 1 {
                                            formExercises.remove(at: index)
                                        }
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(formExercises.count > 1 ? Color.brand.destructive : Color.brand.textSecondary.opacity(0.3))
                                    }
                                    .disabled(formExercises.count == 1)
                                }
                            }
                        }
                        
                        Button(action: { formExercises.append(FormExercise(name: "", repsText: "")) }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Exercise")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.brand.primary)
                        }
                    }
                    
                    // Rounds
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Rounds")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.brand.textPrimary)
                        
                        TextField("20", text: $roundsText)
                            .keyboardType(.numberPad)
                            .customTextField()
                    }
                    
                    // Weight
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Weight (kg)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.brand.textPrimary)
                        
                        TextField("16", text: $weightText)
                            .keyboardType(.numberPad)
                            .customTextField()
                    }
                    
                    // Type
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Type")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.brand.textPrimary)
                        
                        TypeChipSelector(selectedType: $selectedType)
                    }
                    
                    // Style
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Style")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.brand.textPrimary)
                        
                        StyleChipSelector(selectedStyle: $selectedStyle)
                    }
                    // Delete Button (only show when editing)
                    if isEditing {
                        Button(action: deleteBlock) {
                            Text("Delete Block")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(Spacing.md)
                                .background(Color.brand.destructive)
                                .cornerRadius(CornerRadius.sm)
                        }
                    }
                }
                .padding(Spacing.md)
            }
            .background(Color.brand.surface)
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(isEditing ? "Edit Block" : "Add Block")
            .onAppear { 
                if let block = existingBlock {
                    date = block.date
                    formExercises = block.exercises.map { FormExercise(name: $0.name, repsText: "\($0.reps)") }
                    roundsText = "\(block.rounds)"
                    selectedType = block.type
                    selectedStyle = block.style
                    weightText = "\(block.weight)"
                }
                
                
            }
            .sheet(isPresented: $showDatePicker) {
                VStack {
                    DatePicker("Select Date", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                    
                    Button("Done") {
                        showDatePicker = false
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.brand.primary)
                    .foregroundColor(.white)
                    .cornerRadius(CornerRadius.md)
                    .padding(.horizontal)
                }
                .presentationDetents([.medium])
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(Color.brand.textPrimary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveBlock()
                    }
                    .foregroundColor(Color.brand.primary)
                    .disabled(isSaving || !isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        !formExercises.isEmpty &&
        formExercises.allSatisfy { !$0.name.isEmpty && !$0.repsText.isEmpty && Int($0.repsText) != nil && Int($0.repsText)! > 0 } &&
        !roundsText.isEmpty && Int(roundsText) != nil &&
        !weightText.isEmpty && Int(weightText) != nil
    }
    
    private func saveBlock() {
        guard let userId = authService.user?.uid,
              let rounds = Int(roundsText),
              let weight = Int(weightText) else { return }
        
        // Convert form exercises to model exercises
        let exercises = formExercises.compactMap { formEx -> Exercise? in
            guard let reps = Int(formEx.repsText) else { return nil }
            return Exercise(name: formEx.name, reps: reps)
        }
        
        guard !exercises.isEmpty else { return }
        isSaving = true
        
        let block = WorkoutBlock(
            id: isEditing ? existingBlock?.id : nil,
            userId: userId,
            date: date,
            exercises: exercises,
            rounds: rounds,
            type: selectedType,
            style: selectedStyle,
            weight: weight
        )
        
        Task {
            do {
                try await firestoreService.saveBlock(block)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error saving block: \(error)")
                isSaving = false
            }
        }
    }
    
    private func deleteBlock() {
        guard let blockId = existingBlock?.id else { return }
        
        Task {
            do {
                try await firestoreService.deleteBlock(id: blockId)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error deleting block: \(error)")
            }
        }
    }
}

struct TypeChipSelector: View {
    @Binding var selectedType: WorkoutBlock.BlockType
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach([WorkoutBlock.BlockType.emom, .amrap, .sets], id: \.self) { type in
                ChipButton(
                    title: type.rawValue,
                    isSelected: selectedType == type,
                    color: Color.brand.primary,
                    action: { selectedType = type }
                )
            }
        }
    }
}

struct StyleChipSelector: View {
    @Binding var selectedStyle: WorkoutBlock.BlockStyle
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach([WorkoutBlock.BlockStyle.single, .double, .twoHanded], id: \.self) { style in
                ChipButton(
                    title: style.rawValue,
                    isSelected: selectedStyle == style,
                    color: Color.brand.primary,
                    action: { selectedStyle = style }
                )
            }
        }
    }
}

struct ChipButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(isSelected ? color : Color.brand.surface)
                .foregroundColor(isSelected ? .white : Color.brand.textPrimary)
                .cornerRadius(CornerRadius.xl)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.xl)
                        .stroke(Color.brand.border, lineWidth: isSelected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct CustomTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Spacing.md)
            .background(Color.brand.surface)
            .cornerRadius(CornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .stroke(Color.brand.border, lineWidth: 1)
            )
    }
}

extension View {
    func customTextField() -> some View {
        modifier(CustomTextFieldStyle())
    }
}
