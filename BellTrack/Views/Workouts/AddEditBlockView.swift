import SwiftUI
import FirebaseAuth

struct FormBlock: Identifiable {
    let id = UUID()
    var workoutBlockId: String?
    var name: String = ""
    var details: String = ""
    var isTracked: Bool = true
    var trackType: WorkoutBlock.TrackType = .weight
    var trackValue: String = ""
    var trackUnit: String = "kg"
    var createdAt: Date = Date()
}

struct TrackedSuggestion: Identifiable {
    let id = UUID()
    let name: String
    let trackType: WorkoutBlock.TrackType
    let trackUnit: String?
}

struct AddEditWorkoutView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService

    @State private var date = Date()
    @State private var formBlocks: [FormBlock] = [FormBlock()]
    @State private var isSaving = false
    @State private var showDatePicker = false
    @State private var trackedSuggestions: [TrackedSuggestion] = []

    private let firestoreService = FirestoreService()
    private let calendar = Calendar.current

    let workoutDate: Date?              // non-nil when editing an existing day
    let existingBlocks: [WorkoutBlock]  // blocks for that day (edit) or empty (new)

    init(
        workoutDate: Date? = nil,
        existingBlocks: [WorkoutBlock] = []
    ) {
        self.workoutDate = workoutDate
        self.existingBlocks = existingBlocks
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AddEditStyle.sectionSpacing) {
                    DatePickerSection(date: $date, showDatePicker: $showDatePicker)
                    BlocksSection(
                        formBlocks: $formBlocks,
                        suggestions: trackedSuggestions
                    )
                    AddBlockButton(formBlocks: $formBlocks)
                }
                .padding(Spacing.md)
            }
            .background(Color.brand.surface)
            .scrollDismissesKeyboard(.immediately)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(Color.brand.textPrimary)
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(workoutDate != nil ? "Edit Workout" : "Add Workout")
                        .font(TextStyles.title)
                        .foregroundColor(Color.brand.textPrimary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveWorkout()
                    }
                    .font(TextStyles.bodyStrong)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brand.primary)
                    .disabled(isSaving || !isValid)
                }
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(date: $date, showDatePicker: $showDatePicker)
            }
            .onAppear {
                loadExistingData()
                Task {
                    await loadTrackedSuggestions()
                }
            }
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        formBlocks.allSatisfy {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    // MARK: - Track formatting

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
        // If editing an existing workout, set the date to that day
        if let workoutDate = workoutDate {
            date = workoutDate
        }

        // If no existing blocks, just keep a single empty block
        guard !existingBlocks.isEmpty else {
            formBlocks = [FormBlock()]
            return
        }

        // Map existing blocks into form blocks (edit mode)
        formBlocks = existingBlocks.map { block in
            let trackValue = formatTrackValue(block.trackValue, type: block.trackType)
            let trackUnit = block.trackUnit ?? "kg"

            return FormBlock(
                workoutBlockId: block.id,
                name: block.name,
                details: block.details,
                isTracked: true,
                trackType: block.trackType ?? .reps,
                trackValue: trackValue,
                trackUnit: trackUnit,
                createdAt: block.createdAt
            )
        }
    }
    
    // MARK: - Load tracked suggestions (for autocomplete)

    private func loadTrackedSuggestions() async {
        guard let userId = authService.user?.uid else { return }

        do {
            let blocks = try await firestoreService.fetchBlocks(userId: userId)

            // Only blocks that are tracked and have a real metric type (weight/time)
            let tracked = blocks.filter {
                $0.isTracked && ($0.trackType == .weight || $0.trackType == .time)
            }

            // Group only by name to avoid Hashable issues
            let grouped = Dictionary(grouping: tracked) { $0.name }

            var suggestions: [TrackedSuggestion] = []

            for (name, items) in grouped {
                // Most recent by date
                guard
                    let latest = items.sorted(by: { $0.date > $1.date }).first,
                    let type = latest.trackType
                else { continue }

                suggestions.append(
                    TrackedSuggestion(
                        name: name,
                        trackType: type,
                        trackUnit: latest.trackUnit
                    )
                )
            }

            await MainActor.run {
                trackedSuggestions = suggestions.sorted {
                    $0.name.lowercased() < $1.name.lowercased()
                }
            }
        } catch {
            print("Error loading tracked suggestions:", error)
        }
    }

    // MARK: - Save

    private func saveWorkout() {
        guard let userId = authService.user?.uid else { return }
        isSaving = true

        Task {
            do {
                // 1. Delete removed blocks (only affects edit case)
                let existingBlockIds = Set(existingBlocks.compactMap { $0.id })
                let currentBlockIds = Set(formBlocks.compactMap { $0.workoutBlockId })
                let blocksToDelete = existingBlockIds.subtracting(currentBlockIds)

                for blockId in blocksToDelete {
                    try await firestoreService.deleteBlock(id: blockId)
                }

                // 2. Save / update all blocks
                for formBlock in formBlocks {
                    let trimmedName = formBlock.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedName.isEmpty else { continue }

                    var parsedTrackValue: Double? = nil
                    var finalTrackUnit: String? = nil
                    var finalTrackType: WorkoutBlock.TrackType? = nil

                    let type = formBlock.trackType
                    finalTrackType = type

                    switch type {
                    case .time:
                        parsedTrackValue = parseTimeString(formBlock.trackValue)
                        finalTrackUnit = nil

                    case .weight:
                        parsedTrackValue = Double(formBlock.trackValue)
                        finalTrackUnit = formBlock.trackUnit

                    case .reps:
                        parsedTrackValue = Double(formBlock.trackValue)
                        finalTrackUnit = nil
                    }

                    let block = WorkoutBlock(
                        id: formBlock.workoutBlockId,
                        userId: userId,
                        date: calendar.startOfDay(for: date),
                        createdAt: formBlock.createdAt,
                        name: trimmedName,
                        details: formBlock.details.trimmingCharacters(in: .whitespacesAndNewlines),
                        isTracked: true,
                        trackType: finalTrackType,
                        trackValue: parsedTrackValue,
                        trackUnit: finalTrackUnit
                    )

                    try await firestoreService.saveBlock(block)
                }

                await MainActor.run { dismiss() }
            } catch {
                print("Error saving workout: \(error)")
                await MainActor.run { isSaving = false }
            }
        }
    }
}

// MARK: - Sections

struct DatePickerSection: View {
    @Binding var date: Date
    @Binding var showDatePicker: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AddEditStyle.labelToFieldSpacing) {
            Text("Date")
                .font(TextStyles.subtextStrong)
                .foregroundColor(Color.brand.textPrimary)

            Button(action: { showDatePicker = true }) {
                HStack {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(TextStyles.body)
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

struct BlocksSection: View {
    @Binding var formBlocks: [FormBlock]
    let suggestions: [TrackedSuggestion]

    var body: some View {
        ForEach(formBlocks.indices, id: \.self) { index in
            VStack(alignment: .leading, spacing: AddEditStyle.fieldStackSpacing) {

                // DELETE BUTTON ONLY (right-aligned)
                HStack {
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

                BlockFormFields(
                    block: $formBlocks[index],
                    suggestions: suggestions
                )
            }
            .padding(AddEditStyle.blockCardPadding)
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
                Text("Add Movement")
            }
            .font(TextStyles.bodyStrong)
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

// MARK: - Block Form Fields
struct BlockFormFields: View {
    @Binding var block: FormBlock
    let suggestions: [TrackedSuggestion]

    @State private var showSuggestions = false
    @FocusState private var nameFieldFocused: Bool

    // MARK: - Derived metric label

    private var metricLabel: String {
        switch block.trackType {
        case .weight: return "Weight"
        case .time:   return "Time"
        case .reps:   return "Reps"
        }
    }

    // Filter suggestions based on what the user is typing
    private var filteredSuggestions: [TrackedSuggestion] {
        let query = block.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        let lower = query.lowercased()

        return Array(
            suggestions
                .filter {
                    $0.name.lowercased().hasPrefix(lower) &&
                    $0.name.caseInsensitiveCompare(query) != .orderedSame
                }
                .prefix(5)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AddEditStyle.fieldStackSpacing) {

            // NAME
            VStack(alignment: .leading, spacing: AddEditStyle.labelToFieldSpacing) {
                HStack {
                    Text("Movement")
                        .font(TextStyles.subtextStrong)
                        .foregroundColor(Color.brand.textPrimary)
                    Spacer()
                }

                TextField("ABC, Planks, Clean + Press...", text: $block.name)
                    .font(TextStyles.body)
                    .customTextField()
                    .focused($nameFieldFocused)
                    .onChange(of: block.name) { _, _ in
                        showSuggestions = nameFieldFocused && !filteredSuggestions.isEmpty
                    }
                    .onChange(of: nameFieldFocused) { _, hasFocus in
                        if !hasFocus {
                            showSuggestions = false
                        } else {
                            showSuggestions = !filteredSuggestions.isEmpty
                        }
                    }

                // Inline autocomplete from tracked blocks
                if showSuggestions && !filteredSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredSuggestions) { suggestion in
                            Button {
                                block.name = suggestion.name
                                block.isTracked = true
                                block.trackType = suggestion.trackType

                                if suggestion.trackType == .weight {
                                    block.trackUnit = suggestion.trackUnit ?? "kg"
                                }

                                showSuggestions = false
                            } label: {
                                Text(suggestion.name)
                                    .font(TextStyles.subtext)
                                    .foregroundColor(Color.brand.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 8)
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                        }
                    }
                    .background(Color.brand.surface)
                    .cornerRadius(CornerRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .stroke(Color.brand.border, lineWidth: 1)
                    )
                    .padding(.top, 4)
                }
            }

            // MEASUREMENT
            VStack(alignment: .leading, spacing: AddEditStyle.labelToFieldSpacing) {
                Text("Metric")
                    .font(TextStyles.subtextStrong)
                    .foregroundColor(Color.brand.textPrimary)

                HStack(spacing: Spacing.sm) {

                    // 1) DROPDOWN – fixed-ish width
                    Menu {
                        Button("Weight") { block.trackType = .weight }
                        Button("Time")   { block.trackType = .time }
                        Button("Reps")   { block.trackType = .reps }
                    } label: {
                        HStack(spacing: 4) {
                            Text(metricLabel)
                                .font(TextStyles.subtext)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                        }
                        .frame(minWidth: 90, maxWidth: 110)
                        .customTextField()
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.sm)
                                .stroke(Color.brand.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    // 2) VALUE INPUT – takes all remaining space
                    TextField(
                        block.trackType == .time ? "2:30" : "16",
                        text: $block.trackValue
                    )
                    .keyboardType(block.trackType == .time ? .numbersAndPunctuation : .decimalPad)
                    .font(TextStyles.body)
                    .customTextField()
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    // 3) MEASUREMENT – pinned to far right
                    if block.trackType == .weight {
                        Button {
                            block.trackUnit = (block.trackUnit == "lbs") ? "kg" : "lbs"
                        } label: {
                            Text(block.trackUnit)
                                .font(TextStyles.subtext)
                                .foregroundColor(Color.brand.textSecondary)
                                .frame(width: 56)
                                .customTextField()
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                                        .stroke(Color.brand.border, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)

                    } else if block.trackType == .time {
                        Text("mins")
                            .font(TextStyles.subtext)
                            .foregroundColor(Color.brand.textSecondary)
                            .frame(width: 56, height: 40, alignment: .trailing)

                    } else if block.trackType == .reps {
                        Text("reps")
                            .font(TextStyles.subtext)
                            .foregroundColor(Color.brand.textSecondary)
                            .frame(width: 56, height: 40, alignment: .trailing)
                    }
                }
                .frame(maxWidth: .infinity) // ⬅️ whole row full-width
            }

            // DETAILS
            VStack(alignment: .leading, spacing: AddEditStyle.labelToFieldSpacing) {
                Text("Details")
                    .font(TextStyles.subtextStrong)
                    .foregroundColor(Color.brand.textPrimary)

                TextEditor(text: $block.details)
                    .font(TextStyles.body)
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
}

// MARK: - Shared text field style

struct CustomTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Spacing.md)
            .frame(height: 40)
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
