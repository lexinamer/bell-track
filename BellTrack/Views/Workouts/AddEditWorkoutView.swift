import SwiftUI
import FirebaseAuth

// MARK: - Form models

struct FormBlock: Identifiable {
    let id = UUID()
    var workoutBlockId: String?
    var name: String = ""
    var details: String = ""

    // Controls whether this block's fields are shown
    var isExpanded: Bool = true

    // NEW: load + volume as text for the form
    var loadKg: String = ""                           // "16"
    var loadMode: LoadMode = .single     // single / double

    var volumeValue: String = ""                      // "30"
    var volumeKind: VolumeKind = .rounds   // reps / rounds

    var createdAt: Date = Date()
}

struct TrackedSuggestion: Identifiable {
    let id = UUID()
    let name: String
    let lastLoadKg: Double?
    let lastLoadMode: LoadMode?
    let lastVolumeCount: Double?
    let lastVolumeKind: VolumeKind?
}

// MARK: - Main Add/Edit View

struct AddEditWorkoutView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService

    @State private var date = Date()
    @State private var formBlocks: [FormBlock] = [FormBlock()]
    @State private var isSaving = false
    @State private var showDatePicker = false
    @State private var trackedSuggestions: [TrackedSuggestion] = []
    @State private var keyboardHeight: CGFloat = 0
    @State private var keyboardShowObserver: NSObjectProtocol?
    @State private var keyboardHideObserver: NSObjectProtocol?

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
                VStack(alignment: .leading, spacing: AddEditStyle.outerSectionSpacing) {
                    DatePickerSection(date: $date, showDatePicker: $showDatePicker)

                    BlocksSection(
                        formBlocks: $formBlocks,
                        suggestions: trackedSuggestions
                    )
                    .padding(.top, 24)

                    AddBlockButton(formBlocks: $formBlocks)
                        .padding(.top, 20)
                }
                .padding(Spacing.md)
                .padding(.bottom, keyboardHeight + 80)
            }
            .background(Color.brand.surface)
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(Color.brand.textPrimary)
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(workoutDate != nil ? "Edit Workout" : "Log Workout")
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
                Task { await loadTrackedSuggestions() }

                keyboardShowObserver = NotificationCenter.default.addObserver(
                    forName: UIResponder.keyboardWillShowNotification,
                    object: nil,
                    queue: .main
                ) { notification in
                    guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                    // Subtract bottom safe-area inset so we don't over-pad
                    let bottomInset = UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .flatMap { $0.windows }
                        .first { $0.isKeyWindow }?
                        .safeAreaInsets.bottom ?? 0
                    keyboardHeight = frame.height - bottomInset
                }

                keyboardHideObserver = NotificationCenter.default.addObserver(
                    forName: UIResponder.keyboardWillHideNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    keyboardHeight = 0
                }
            }
            .onDisappear {
                if let showToken = keyboardShowObserver {
                    NotificationCenter.default.removeObserver(showToken)
                    keyboardShowObserver = nil
                }
                if let hideToken = keyboardHideObserver {
                    NotificationCenter.default.removeObserver(hideToken)
                    keyboardHideObserver = nil
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

        func formatNumber(_ value: Double?) -> String {
            guard let value else { return "" }
            return value.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(value))
                : String(value)
        }

        // Map existing blocks into form blocks (edit mode)
        formBlocks = existingBlocks.map { block in
            FormBlock(
                workoutBlockId: block.id,
                name: block.name,
                details: block.details,
                loadKg: formatNumber(block.loadKg),
                loadMode: block.loadMode ?? .single,
                volumeValue: formatNumber(block.volumeCount),
                volumeKind: block.volumeKind ?? .rounds,
                createdAt: block.createdAt
            )
        }
    }

    // MARK: - Load tracked suggestions (for autocomplete)

    private func loadTrackedSuggestions() async {
        guard let userId = authService.user?.uid else { return }

        do {
            let blocks = try await firestoreService.fetchBlocks(userId: userId)

            // Take only tracked blocks
            let trackedBlocks = blocks.filter { $0.isTracked }

            // For each set name (case-insensitive), keep the most recent block
            var latestByName: [String: WorkoutBlock] = [:]

            for block in trackedBlocks {
                let key = block.name
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()

                guard !key.isEmpty else { continue }

                if let existing = latestByName[key] {
                    // Prefer newer date / createdAt
                    if block.date > existing.date ||
                        (block.date == existing.date && block.createdAt > existing.createdAt) {
                        latestByName[key] = block
                    }
                } else {
                    latestByName[key] = block
                }
            }

            let suggestions = latestByName.values
                .sorted { $0.name.lowercased() < $1.name.lowercased() }
                .map { block in
                    TrackedSuggestion(
                        name: block.name,
                        lastLoadKg: block.loadKg,
                        lastLoadMode: block.loadMode,
                        lastVolumeCount: block.volumeCount,
                        lastVolumeKind: block.volumeKind
                    )
                }

            await MainActor.run {
                trackedSuggestions = suggestions
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
                // 1. Figure out which existing blocks were removed (edit case)
                let existingBlockIds = Set(existingBlocks.compactMap { $0.id })
                let currentBlockIds  = Set(formBlocks.compactMap { $0.workoutBlockId })
                let blocksToDelete   = existingBlockIds.subtracting(currentBlockIds)

                // 2. Delete removed blocks
                for blockId in blocksToDelete {
                    try await firestoreService.deleteBlock(id: blockId)
                }

                // 3. Save / update all current blocks
                for formBlock in formBlocks {
                    let trimmedName = formBlock.name
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedName.isEmpty else { continue }

                    var parsedVolumeCount: Double? = nil
                    var finalVolumeKind: VolumeKind? = nil

                    // Volume: number + kind
                    if !formBlock.volumeValue.isEmpty,
                       let count = Double(formBlock.volumeValue) {
                        parsedVolumeCount = count
                        finalVolumeKind = formBlock.volumeKind
                    }

                    let block = WorkoutBlock(
                        id: formBlock.workoutBlockId,
                        userId: userId,
                        date: calendar.startOfDay(for: date),
                        createdAt: formBlock.createdAt,
                        name: trimmedName,
                        details: formBlock.details
                            .trimmingCharacters(in: .whitespacesAndNewlines),
                        isTracked: true,
                        loadKg: Double(formBlock.loadKg),
                        loadMode: formBlock.loadMode,
                        volumeCount: parsedVolumeCount,
                        volumeKind: finalVolumeKind
                    )

                    try await firestoreService.saveBlock(block)
                }
            } catch {
                print("Error saving workout: \(error)")
            }

            // Always close the screen at the end, even if there was an error
            await MainActor.run {
                isSaving = false
                dismiss()
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
                .font(TextStyles.bodyStrong)
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

                // Header: label + expand/collapse + delete
                HStack(alignment: .center) {
                    Text("Block")
                        .font(TextStyles.bodyStrong)
                        .foregroundColor(Color.brand.textPrimary)

                    Spacer()

                    Button(action: {
                        withAnimation {
                            formBlocks[index].isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: formBlocks[index].isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.brand.textSecondary)
                    }

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

                if formBlocks[index].isExpanded {
                    BlockFormFields(
                        block: $formBlocks[index],
                        suggestions: suggestions
                    )
                }
            }
            .padding(.vertical, AddEditStyle.blockCardPadding)
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
                // Collapse existing blocks to free up screen space
                for idx in formBlocks.indices {
                    formBlocks[idx].isExpanded = false
                }
                // Add a new expanded block
                formBlocks.append(FormBlock())
            }
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Block")
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

    private static func formatNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        } else {
            return String(value)
        }
    }

    // Filter suggestions based on what the user is typing
    private var filteredSuggestions: [TrackedSuggestion] {
        let query = block.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        return Array(
            suggestions
                .filter {
                    // Case‑insensitive prefix match
                    $0.name.range(of: query,
                                  options: [.caseInsensitive, .anchored]) != nil
                    &&
                    // Exclude exact case‑insensitive match
                    $0.name.compare(query,
                                    options: .caseInsensitive) != .orderedSame
                }
                .prefix(5)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AddEditStyle.movementFieldGroupSpacing) {

            // NAME
            VStack(alignment: .leading, spacing: AddEditStyle.labelToFieldSpacing) {
                HStack {
                    Text("Name")
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
                                // Set the set name from the suggestion
                                block.name = suggestion.name

                                // If we have stored metrics for this set, prefill them
                                if let kg = suggestion.lastLoadKg {
                                    block.loadKg = BlockFormFields.formatNumber(kg)
                                }

                                if let mode = suggestion.lastLoadMode {
                                    block.loadMode = mode
                                }

                                if let volume = suggestion.lastVolumeCount {
                                    block.volumeValue = BlockFormFields.formatNumber(volume)
                                }

                                if let kind = suggestion.lastVolumeKind {
                                    block.volumeKind = kind
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

            // LOAD
            VStack(alignment: .leading, spacing: AddEditStyle.labelToFieldSpacing) {
                Text("Weight")
                    .font(TextStyles.subtextStrong)
                    .foregroundColor(Color.brand.textPrimary)

                HStack(spacing: Spacing.sm) {
                    // Weight input
                    TextField("16", text: $block.loadKg)
                        .keyboardType(.decimalPad)
                        .font(TextStyles.body)
                        .customTextField()
                        .frame(maxWidth: .infinity)
                        .layoutPriority(1)

                    Text("kg")
                        .font(TextStyles.subtext)
                        .foregroundColor(Color.brand.textSecondary)
                        .frame(width: 24, alignment: .leading)

                    Spacer(minLength: Spacing.sm)

                    // Single / Double
                    Picker("", selection: $block.loadMode) {
                        Text("Single").tag(LoadMode.single)
                        Text("Double").tag(LoadMode.double)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 170)
                }
                .padding(.top, 4)
            }

            // VOLUME
            VStack(alignment: .leading, spacing: AddEditStyle.labelToFieldSpacing) {
                Text("Total")
                    .font(TextStyles.subtextStrong)
                    .foregroundColor(Color.brand.textPrimary)

                HStack(spacing: Spacing.sm) {
                    TextField("30", text: $block.volumeValue)
                        .keyboardType(.numberPad)
                        .font(TextStyles.body)
                        .customTextField()
                        .frame(maxWidth: .infinity)
                        .layoutPriority(1)

                    Spacer(minLength: Spacing.sm)

                    Picker("", selection: $block.volumeKind) {
                        Text("Rounds").tag(VolumeKind.rounds)
                        Text("Reps").tag(VolumeKind.reps)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                .padding(.top, 4)
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
