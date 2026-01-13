import SwiftUI
import FirebaseAuth

struct AddEditBlockView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService

    private let firestoreService = FirestoreService()

    let existingBlock: Block?
    let onSave: (Block) -> Void

    @State private var name: String
    @State private var startDate: Date
    @State private var durationWeeks: Int?
    @State private var didChangeDuration: Bool
    @State private var notes: String

    private var isEditing: Bool { existingBlock != nil }
    private var navTitle: String { isEditing ? "Edit Block" : "Create Block" }

    init(_ existingBlock: Block? = nil, onSave: @escaping (Block) -> Void) {
        self.existingBlock = existingBlock
        self.onSave = onSave

        _name = State(initialValue: existingBlock?.name ?? "")
        _startDate = State(initialValue: existingBlock?.startDate ?? Date())

        let existingEnd = existingBlock?.endDate

        // If editing an existing block with an endDate, infer weeks for chip selection if it matches allowed durations.
        let inferredWeeks: Int? = {
            guard let end = existingEnd else { return nil }
            let cal = Calendar.current
            let startDay = cal.startOfDay(for: existingBlock?.startDate ?? Date())
            let endDay = cal.startOfDay(for: end)
            let days = cal.dateComponents([.day], from: startDay, to: endDay).day ?? 0
            let totalDays = max(1, days + 1)
            return Int(ceil(Double(totalDays) / 7.0))
        }()

        let allowedDurations: Set<Int> = [4, 6, 8, 10, 12]
        let duration = (inferredWeeks != nil && allowedDurations.contains(inferredWeeks!)) ? inferredWeeks : nil
        _durationWeeks = State(initialValue: duration)

        _didChangeDuration = State(initialValue: false)
        _notes = State(initialValue: existingBlock?.notes ?? "")
    }

    // MARK: - Derived

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNotes: String? {
        let t = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private var canSave: Bool { !trimmedName.isEmpty }

    private var computedEndDate: Date? {
        guard let weeks = durationWeeks else { return nil }
        let days = (weeks * 7) - 1
        return Calendar.current.date(
            byAdding: .day,
            value: days,
            to: Calendar.current.startOfDay(for: startDate)
        )
    }

    /// End date stored in Firestore:
    /// - If duration selected → computed end date
    /// - If editing and user never touched duration → keep existing endDate as-is
    /// - If user explicitly sets Ongoing → nil
    private var endDateToSave: Date? {
        if durationWeeks != nil { return computedEndDate }
        if !didChangeDuration { return existingBlock?.endDate }
        return nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brand.surface.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Layout.sectionSpacing) {

                        // Name
                        VStack(alignment: .leading, spacing: Layout.contentSpacing) {
                            FormLabel(text: "Name")
                            FormTextField(placeholder: "Full Body Strength", text: $name)
                        }

                        // Start Date (popup calendar handled inside FormDateField)
                        FormDateField(label: "Start Date", date: $startDate)

                        // Duration
                        VStack(alignment: .leading, spacing: Layout.contentSpacing) {
                            FormLabel(text: "Duration")

                            LazyVGrid(
                                columns: Array(
                                    repeating: GridItem(.flexible(), spacing: Layout.contentSpacing),
                                    count: 3
                                ),
                                spacing: Layout.contentSpacing
                            ) {
                                FormChip(title: "4 weeks", isSelected: durationWeeks == 4) {
                                    durationWeeks = 4
                                    didChangeDuration = true
                                }

                                FormChip(title: "6 weeks", isSelected: durationWeeks == 6) {
                                    durationWeeks = 6
                                    didChangeDuration = true
                                }

                                FormChip(title: "8 weeks", isSelected: durationWeeks == 8) {
                                    durationWeeks = 8
                                    didChangeDuration = true
                                }

                                FormChip(title: "10 weeks", isSelected: durationWeeks == 10) {
                                    durationWeeks = 10
                                    didChangeDuration = true
                                }

                                FormChip(title: "12 weeks", isSelected: durationWeeks == 12) {
                                    durationWeeks = 12
                                    didChangeDuration = true
                                }

                                FormChip(title: "Ongoing", isSelected: durationWeeks == nil) {
                                    durationWeeks = nil
                                    didChangeDuration = true
                                }
                            }

                            // Helper text (computed end date)
                            if let end = computedEndDate {
                                Text("Ends on \(end.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))")
                                    .font(TextStyles.bodySmall)
                                    .foregroundColor(Color.brand.textSecondary)
                            }
                        }

                        // Notes
                        VStack(alignment: .leading, spacing: Layout.contentSpacing) {
                            FormLabel(text: "Notes")
                            FormTextEditor(placeholder: "Optional", text: $notes)
                        }
                    }
                    .padding(.horizontal, Layout.horizontalSpacing)
                    .padding(.vertical, Layout.listSpacing)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(TextStyles.linkSmall)
                            .foregroundColor(Color.brand.textPrimary)
                    }
                    .buttonStyle(.plain)
                }

                ToolbarItem(placement: .principal) {
                    Text(navTitle)
                        .font(TextStyles.title)
                        .foregroundColor(Color.brand.textPrimary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    FormSaveButton(isEnabled: canSave) {
                        Task {
                            await saveAndDismiss()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Save

    private func saveAndDismiss() async {
        guard canSave, let userId = authService.user?.uid else { return }

        let id = existingBlock?.id
        let createdAt = existingBlock?.createdAt ?? Date()

        let updated = Block(
            id: id,
            userId: userId,
            name: trimmedName,
            notes: trimmedNotes,
            startDate: startDate,
            endDate: endDateToSave,
            createdAt: createdAt,
            updatedAt: Date()
        )

        onSave(updated)
        dismiss()
    }
}
