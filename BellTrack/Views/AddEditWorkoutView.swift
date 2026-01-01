import SwiftUI
import FirebaseAuth

struct FormBlock: Identifiable {
    let id = UUID()
    var workoutBlockId: String? // For existing blocks
    var name: String = ""
    var details: String = ""
    var isTracked: Bool = false             // For insights / progress
    var trackType: WorkoutBlock.TrackType = .weight
    var trackValue: String = ""
    var trackUnit: String = "kg"
    var createdAt: Date = Date()
}

struct AddEditWorkoutView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    
    @State private var date = Date()
    @State private var notes = ""
    @State private var formBlocks: [FormBlock] = [FormBlock()]
    @State private var isSaving = false
    @State private var showDatePicker = false
    
    private let firestoreService = FirestoreService()
    
    let workoutDate: Date?              // Date we're editing (if editing)
    let existingBlocks: [WorkoutBlock]  // All blocks for this date
    let existingNote: DateNote?         // Note for this date
    
    init(
        workoutDate: Date? = nil,
        existingBlocks: [WorkoutBlock] = [],
        existingNote: DateNote? = nil
    ) {
        self.workoutDate = workoutDate
        self.existingBlocks = existingBlocks
        self.existingNote = existingNote
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    DatePickerSection(date: $date, showDatePicker: $showDatePicker)
                    
                    NotesSection(notes: $notes)
                    
                    BlocksSection(formBlocks: $formBlocks)
                    
                    AddBlockButton(formBlocks: $formBlocks)
                }
                .padding(Spacing.md)
            }
            .background(Color.brand.background)
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(workoutDate != nil ? "Edit Workout" : "Add Workout")
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
                        saveWorkout()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brand.secondary)
                    .disabled(isSaving || !isValid)
                }
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(date: $date, showDatePicker: $showDatePicker)
            }
            .onAppear {
                loadExistingData()
            }
        }
    }
    
    // MARK: - Validation
    
    private var isValid: Bool {
        formBlocks.allSatisfy {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    // MARK: - Track formatting helpers
    
    private func formatTrackValue(_ value: Double?, type: WorkoutBlock.TrackType?) -> String {
        guard let value = value else { return "" }
        
        if type == .time {
            let minutes = Int(value) / 60
            let seconds = Int(value) % 60
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return value.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(value))
                : String(value)
        }
    }
    
    private func parseTimeString(_ timeString: String) -> Double? {
        if timeString.contains(":") {
            let parts = timeString.split(separator: ":")
            guard parts.count == 2,
                  let minutes = Double(parts[0]),
                  let seconds = Double(parts[1]) else { return nil }
            return (minutes * 60) + seconds
        } else {
            return Double(timeString)
        }
    }
    
    // MARK: - Load existing data
    
    private func loadExistingData() {
        guard let workoutDate = workoutDate else { return }
        
        date = workoutDate
        notes = existingNote?.note ?? ""
        
        if existingBlocks.isEmpty {
            formBlocks = [FormBlock()]
            return
        }
        
        formBlocks = existingBlocks.map { block in
            let trackValue = formatTrackValue(block.trackValue, type: block.trackType)
            let trackUnit = block.trackUnit ?? "kg"
            
            return FormBlock(
                workoutBlockId: block.id,
                name: block.name,
                details: block.details,
                isTracked: block.isTracked,
                trackType: block.trackType ?? .none,
                trackValue: trackValue,
                trackUnit: trackUnit,
                createdAt: block.createdAt
            )
        }
    }
    
    // MARK: - Save
    
    private func saveWorkout() {
        guard let userId = authService.user?.uid else { return }
        
        isSaving = true
        
        Task {
            do {
                // 1. Delete removed blocks
                let existingBlockIds = Set(existingBlocks.compactMap { $0.id })
                let currentBlockIds = Set(formBlocks.compactMap { $0.workoutBlockId })
                let blocksToDelete = existingBlockIds.subtracting(currentBlockIds)
                
                for blockId in blocksToDelete {
                    try await firestoreService.deleteBlock(id: blockId)
                }
                
                // 2. Save/update all blocks
                for formBlock in formBlocks {
                    let trimmedName = formBlock.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedName.isEmpty else { continue }
                    
                    var parsedTrackValue: Double? = nil
                    var finalTrackUnit: String? = nil
                    var finalTrackType: WorkoutBlock.TrackType? = nil
                    
                    // Save metric whenever a type is selected (except .none),
                    // regardless of whether "Track" toggle is on.
                    if formBlock.trackType != .none {
                        finalTrackType = formBlock.trackType
                        
                        if formBlock.trackType == .time {
                            parsedTrackValue = parseTimeString(formBlock.trackValue)
                            finalTrackUnit = nil
                        } else if formBlock.trackType == .weight {
                            parsedTrackValue = Double(formBlock.trackValue)
                            finalTrackUnit = formBlock.trackUnit
                        }
                    }
                    
                    let block = WorkoutBlock(
                        id: formBlock.workoutBlockId,
                        userId: userId,
                        date: date,
                        createdAt: formBlock.createdAt,
                        name: trimmedName,
                        details: formBlock.details.trimmingCharacters(in: .whitespacesAndNewlines),
                        isTracked: formBlock.isTracked,   // only for insights / dot in list
                        trackType: finalTrackType,        // metric to show in list + insights
                        trackValue: parsedTrackValue,
                        trackUnit: finalTrackUnit
                    )
                    
                    try await firestoreService.saveBlock(block)
                }
                
                // 3. Save or delete the note
                let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                let startOfDay = Calendar.current.startOfDay(for: date)
                
                if !trimmedNotes.isEmpty {
                    let note = DateNote(
                        id: existingNote?.id,
                        userId: userId,
                        date: startOfDay,
                        note: trimmedNotes
                    )
                    try await firestoreService.saveDateNote(note)
                } else if let noteId = existingNote?.id {
                    // Delete note if it exists but is now empty
                    try await firestoreService.deleteDateNote(id: noteId)
                }
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error saving workout: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Sections & Subviews

struct DatePickerSection: View {
    @Binding var date: Date
    @Binding var showDatePicker: Bool
    
    var body: some View {
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
    }
}

struct NotesSection: View {
    @Binding var notes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Notes (optional)")
                .font(.system(size: Typography.sm, weight: .semibold))
                .foregroundColor(Color.brand.textPrimary)
            
            TextEditor(text: $notes)
                .font(.system(size: Typography.md))
                .frame(minHeight: 60)
                .padding(Spacing.sm)
                .background(Color.brand.surface)
                .cornerRadius(CornerRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .stroke(Color.brand.border, lineWidth: 1)
                )
        }
    }
}

struct BlocksSection: View {
    @Binding var formBlocks: [FormBlock]
    
    var body: some View {
        ForEach(formBlocks.indices, id: \.self) { index in
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("Block \(index + 1)")
                        .font(.system(size: Typography.md, weight: .bold))
                        .foregroundColor(Color.brand.textPrimary)
                    
                    Spacer()
                    
                    if formBlocks.count > 1 {
                        Button(action: {
                            withAnimation {
                                _ = formBlocks.remove(at: index)
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(Color.brand.destructive)
                        }
                    }
                }
                
                BlockFormFields(block: $formBlocks[index])
            }
            .padding(Spacing.xs)
            .background(Color.brand.surface)
            .cornerRadius(CornerRadius.md)
        }
    }
}

struct AddBlockButton: View {
    @Binding var formBlocks: [FormBlock]
    
    var body: some View {
        Button {
            withAnimation {
                formBlocks.append(FormBlock())
            }
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Block")
            }
            .font(.system(size: Typography.md, weight: .semibold))
            .foregroundColor(Color.brand.primary)
        }
    }
}

struct DatePickerSheet: View {
    @Binding var date: Date
    @Binding var showDatePicker: Bool
    
    var body: some View {
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
}

struct BlockFormFields: View {
    @Binding var block: FormBlock
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Name + Track
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Name")
                        .font(.system(size: Typography.sm, weight: .semibold))
                        .foregroundColor(Color.brand.textPrimary)
                    
                    Spacer()
                    
                    Button(action: { block.isTracked.toggle() }) {
                        Image(systemName: block.isTracked ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(
                                block.isTracked
                                ? Color.brand.primary
                                : Color.brand.textSecondary
                            )
                            .font(.system(size: Typography.lg))
                    }
                    
                    Text("Track progress")
                        .font(.system(size: Typography.sm))
                        .foregroundColor(Color.brand.textSecondary)
                }
                
                TextField("ABC Complex", text: $block.name)
                    .customTextField()
            }
            
            // Track metric (always visible)
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Metric")
                    .font(.system(size: Typography.sm, weight: .semibold))
                    .foregroundColor(Color.brand.textPrimary)
                
                Picker("", selection: $block.trackType) {
                    Text("Weight").tag(WorkoutBlock.TrackType.weight)
                    Text("Time").tag(WorkoutBlock.TrackType.time)
                    Text("None").tag(WorkoutBlock.TrackType.none)
                }
                .pickerStyle(.segmented)
            }
            
            // Weight field (conditional)
            if block.trackType == .weight {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Weight")
                        .font(.system(size: Typography.sm, weight: .semibold))
                        .foregroundColor(Color.brand.textPrimary)
                    
                    HStack(spacing: Spacing.md) {
                        TextField("16", text: $block.trackValue)
                            .keyboardType(.decimalPad)
                            .customTextField()
                            .frame(maxWidth: .infinity)
                        
                        Picker("", selection: $block.trackUnit) {
                            Text("kg").tag("kg")
                            Text("lbs").tag("lbs")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 100)
                    }
                }
            }
            
            // Time field (conditional)
            if block.trackType == .time {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Time")
                        .font(.system(size: Typography.sm, weight: .semibold))
                        .foregroundColor(Color.brand.textPrimary)
                    
                    TextField("2:30", text: $block.trackValue)
                        .keyboardType(.numbersAndPunctuation)
                        .customTextField()
                }
            }
            
            // Details
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Details")
                    .font(.system(size: Typography.sm, weight: .semibold))
                    .foregroundColor(Color.brand.textPrimary)
                
                TextEditor(text: $block.details)
                    .font(.system(size: Typography.md))
                    .frame(minHeight: 60)
                    .padding(Spacing.sm)
                    .background(Color.brand.background)
                    .cornerRadius(CornerRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .stroke(Color.brand.border, lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: - Shared text field style

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


#Preview("Add/Edit Workout") {
    // Replace AuthService() with your preview/mock init if needed
    let authService = AuthService()
    
    return NavigationStack {
        AddEditWorkoutView()
            .environmentObject(authService)
    }
}

