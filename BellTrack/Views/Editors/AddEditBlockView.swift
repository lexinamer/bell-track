import SwiftUI
import FirebaseAuth

struct AddEditBlockView: View {

    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService

    // MARK: - Inputs
    let existingBlock: Block?
    let onSave: (Block) -> Void

    // MARK: - State
    @State private var name: String
    @State private var startDate: Date
    @State private var durationWeeks: Int?
    @State private var didChangeDuration: Bool
    @State private var notes: String

    private var isEditing: Bool { existingBlock?.id != nil }
    private var navTitle: String { isEditing ? "Edit Block" : "New Block" }

    // MARK: - Init
    init(_ existingBlock: Block? = nil, onSave: @escaping (Block) -> Void) {
        self.existingBlock = existingBlock
        self.onSave = onSave

        _name = State(initialValue: existingBlock?.name ?? "")
        _startDate = State(initialValue: existingBlock?.startDate ?? Date())
        _notes = State(initialValue: existingBlock?.notes ?? "")
        _didChangeDuration = State(initialValue: false)

        // Infer duration from existing end date (if possible)
        let inferredWeeks: Int? = {
            guard
                let block = existingBlock,
                let end = block.endDate
            else { return nil }

            let cal = Calendar.current
            let startDay = cal.startOfDay(for: block.startDate)
            let endDay = cal.startOfDay(for: end)
            let days = cal.dateComponents([.day], from: startDay, to: endDay).day ?? 0
            let totalDays = max(1, days + 1)
            return Int(ceil(Double(totalDays) / 7.0))
        }()

        let allowed: Set<Int> = [4, 6, 8, 10, 12]
        _durationWeeks = State(initialValue: (inferredWeeks != nil && allowed.contains(inferredWeeks!)) ? inferredWeeks : nil)
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
    /// - Duration selected → computed
    /// - Editing + duration untouched → keep existing
    /// - Ongoing → nil
    private var endDateToSave: Date? {
        if durationWeeks != nil { return computedEndDate }
        if !didChangeDuration { return existingBlock?.endDate }
        return nil
    }

    private var endDateHint: String? {
        guard let end = computedEndDate else { return nil }
        return "Ends on \(end.formatted(.dateTime.month(.abbreviated).day().year()))"
    }

    // MARK: - View

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {

                    fieldLabel("Name")
                    TextField("Full Body Strength", text: $name)
                        .font(Theme.Font.body)
                        .padding()
                        .background(Color.brand.surface)
                        .cornerRadius(Theme.Radius.sm)

                    fieldLabel("Start Date")
                    DatePicker("", selection: $startDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)

                    fieldLabel("Duration")
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Space.sm), count: 3),
                        spacing: Theme.Space.sm
                    ) {
                        durationChip("4 weeks", 4)
                        durationChip("6 weeks", 6)
                        durationChip("8 weeks", 8)
                        durationChip("10 weeks", 10)
                        durationChip("12 weeks", 12)
                        durationChip("Ongoing", nil)
                    }

                    if let hint = endDateHint {
                        Text(hint)
                            .font(Theme.Font.meta)
                            .foregroundColor(Color.brand.textSecondary)
                            .padding(.top, Theme.Space.sm)
                    }

                    fieldLabel("Notes (optional)")
                    TextEditor(text: $notes)
                        .font(Theme.Font.body)
                        .frame(minHeight: 140)
                        .padding(8)
                        .background(Color.brand.surface)
                        .cornerRadius(Theme.Radius.sm)
                }
                .padding(Theme.Space.lg)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.brand.textPrimary)
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(navTitle)
                        .font(Theme.Font.title)
                        .foregroundColor(Color.brand.textPrimary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveAndDismiss() }
                        .disabled(!canSave)
                        .font(Theme.Font.link)
                }
            }
        }
    }

    // MARK: - UI helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.Font.meta)
            .foregroundColor(Color.brand.textSecondary)
    }

    @ViewBuilder
    private func durationChip(_ title: String, _ weeks: Int?) -> some View {
        let isSelected = durationWeeks == weeks

        Button {
            durationWeeks = weeks
            didChangeDuration = true
        } label: {
            Text(title)
                .font(Theme.Font.body)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.sm)
                .background(isSelected ? Color.brand.primary : Color.brand.surface)
                .foregroundColor(isSelected ? .white : Color.brand.textPrimary)
                .cornerRadius(Theme.Radius.sm)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save

    private func saveAndDismiss() {
        guard canSave, let userId = authService.user?.uid else { return }

        let updated = Block(
            id: existingBlock?.id,
            userId: userId,
            name: trimmedName,
            notes: trimmedNotes,
            startDate: startDate,
            endDate: endDateToSave,
            createdAt: existingBlock?.createdAt ?? Date(),
            updatedAt: Date()
        )

        onSave(updated)
        dismiss()
    }
}
