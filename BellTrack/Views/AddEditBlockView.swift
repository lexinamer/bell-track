import SwiftUI
import FirebaseAuth

struct AddEditBlockView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @State private var date = Date()
    @State private var formExercises: [FormExercise] = [FormExercise(name: "", repsText: "")]
    @State private var roundsText = ""
    @State private var selectedType: WorkoutBlock.BlockType? = nil  // Now optional
    @State private var selectedStyle: WorkoutBlock.BlockStyle? = nil  // Now optional
    @State private var selectedUnit: String = "kg"
    @State private var weightText = ""
    @State private var timeText = ""  // New
    @State private var selectedTimeUnit: String = "sec"  // New
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
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Date
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Date")
                            .font(.system(size: Typography.sm, weight: .semibold))
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
                                            .font(.system(size: Typography.sm, weight: .semibold))
                                            .foregroundColor(Color.brand.textPrimary)
                                    }
                                    TextField("Exercise name", text: $formExercises[index].name)
                                        .customTextField()
                                }
                                
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    if index == 0 {
                                        Text("Reps (optional)")
                                            .font(.system(size: Typography.sm, weight: .semibold))
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
                        Button {
                            withAnimation(nil) {
                                formExercises.append(FormExercise(name: "", repsText: ""))
                            }
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Exercise")
                            }
                            .font(.system(size: Typography.sm, weight: .semibold))
                            .foregroundColor(Color.brand.primary)
                        }
                    }
                        
                    // Rounds
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Rounds")
                            .font(.system(size: Typography.sm, weight: .semibold))
                            .foregroundColor(Color.brand.textPrimary)
                        
                        TextField("20", text: $roundsText)
                            .keyboardType(.numberPad)
                            .customTextField()
                    }
                    
                    // Weight
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Weight (optional)")
                            .font(.system(size: Typography.sm, weight: .semibold))
                            .foregroundColor(Color.brand.textPrimary)
                        
                        HStack(spacing: Spacing.md) {
                            TextField("16", text: $weightText)
                                .keyboardType(.numberPad)
                                .customTextField()
                                .frame(maxWidth: .infinity)
                            
                            Picker("", selection: $selectedUnit) {
                                Text("kg").tag("kg")
                                Text("lbs").tag("lbs")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 100)
                        }
                    }
                    
                    // Time (optional)
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Time (optional)")
                            .font(.system(size: Typography.sm, weight: .semibold))
                            .foregroundColor(Color.brand.textPrimary)
                        
                        HStack(spacing: Spacing.md) {
                            TextField("30", text: $timeText)
                                .keyboardType(.decimalPad)
                                .customTextField()
                                .frame(maxWidth: .infinity)
                            
                            Picker("", selection: $selectedTimeUnit) {
                                Text("sec").tag("sec")
                                Text("min").tag("min")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 100)
                        }
                    }
                    
                    // Type
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Type (optional)")
                            .font(.system(size: Typography.sm, weight: .semibold))
                            .foregroundColor(Color.brand.textPrimary)
                        
                        TypeChipSelector(selectedType: $selectedType)
                    }
                    
                    // Style
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Style (optional)")
                            .font(.system(size: Typography.sm, weight: .semibold))
                            .foregroundColor(Color.brand.textPrimary)
                        
                        StyleChipSelector(selectedStyle: $selectedStyle)
                    }
                    // Delete Button (only show when editing)
                    if isEditing {
                        Button(action: deleteBlock) {
                            Text("Delete Block")
                                .font(.system(size: Typography.md, weight: .semibold))
                                .foregroundColor(Color.brand.destructive)
                                .frame(maxWidth: .infinity)
                                .padding(Spacing.md)
                                .background(Color.brand.surface)
                                .cornerRadius(CornerRadius.sm)
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                                        .stroke(Color.brand.destructive, lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(Spacing.md)
            }
            .background(Color.brand.background)
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(isEditing ? "Edit Block" : "Add Block")
            .onAppear {
                if let block = existingBlock {
                    date = block.date
                    formExercises = block.exercises.map {
                        FormExercise(
                            name: $0.name,
                            repsText: $0.reps.map { String($0) } ?? ""
                        )
                    }
                    roundsText = "\(block.rounds)"
                    selectedType = block.type
                    selectedStyle = block.style
                    weightText = block.weight.map { String($0) } ?? ""
                    selectedUnit = block.unit
                    timeText = block.time.map { String($0) } ?? ""
                    selectedTimeUnit = block.timeUnit ?? "sec"
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
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(Color.brand.textPrimary)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveBlock()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brand.secondary)
                    .disabled(isSaving || !isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        !formExercises.isEmpty &&
        formExercises.allSatisfy { !$0.name.isEmpty } &&  // Only name required now
        !roundsText.isEmpty && Int(roundsText) != nil
    }
    
    private func saveBlock() {
        guard let userId = authService.user?.uid,
              let rounds = Int(roundsText) else { return }
        
        // Convert optional fields
        let weight = weightText.isEmpty ? nil : Int(weightText)
        let time = timeText.isEmpty ? nil : Double(timeText)

        // Convert form exercises to model exercises
        let exercises = formExercises.compactMap { formEx -> Exercise? in
            guard !formEx.name.isEmpty else { return nil }
            let reps = formEx.repsText.isEmpty ? nil : Int(formEx.repsText)
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
            weight: weight,
            unit: selectedUnit,
            time: time,
            timeUnit: time != nil ? selectedTimeUnit : nil
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
    @Binding var selectedType: WorkoutBlock.BlockType?  // Now optional
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach([WorkoutBlock.BlockType.emom, .amrap, .sets], id: \.self) { type in
                ChipButton(
                    title: type.rawValue,
                    isSelected: selectedType == type,
                    color: Color.brand.primary,
                    action: {
                        selectedType = selectedType == type ? nil : type  // Toggle on/off
                    }
                )
            }
        }
    }
}

struct StyleChipSelector: View {
    @Binding var selectedStyle: WorkoutBlock.BlockStyle?  // Now optional
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach([WorkoutBlock.BlockStyle.single, .double, .twoHanded], id: \.self) { style in
                ChipButton(
                    title: style.rawValue,
                    isSelected: selectedStyle == style,
                    color: Color.brand.primary,
                    action: {
                        selectedStyle = selectedStyle == style ? nil : style  // Toggle on/off
                    }
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
                .font(.system(size: Typography.md, weight: .medium))
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
            .background(Color.brand.background)
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
