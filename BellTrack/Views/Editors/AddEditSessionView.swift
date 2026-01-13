import SwiftUI

struct AddEditSessionView: View {

    @Environment(\.dismiss) private var dismiss

    let block: Block
    let existingSession: Session?

    let onSave: (Session) -> Void
    let onDelete: (() -> Void)?

    @State private var date: Date
    @State private var details: String

    private var isEditing: Bool { existingSession != nil }

    init(
        block: Block,
        session: Session? = nil,
        onSave: @escaping (Session) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.block = block
        self.existingSession = session
        self.onSave = onSave
        self.onDelete = onDelete

        _date = State(initialValue: session?.date ?? Date())
        _details = State(initialValue: session?.details ?? "")
    }

    private var trimmedDetails: String {
        details.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool { !trimmedDetails.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {

                    fieldLabel("Date")

                    DatePicker(
                        "",
                        selection: $date,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .stroke(Color.brand.border, lineWidth: 1)
                    )
                    .cornerRadius(Theme.Radius.sm)

                    fieldLabel("Details")

                    TextEditor(text: $details)
                        .font(Theme.Font.body)
                        .frame(minHeight: 140) // smaller so the sheet feels “compact”
                        .padding(10)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .stroke(Color.brand.border, lineWidth: 1)
                        )
                        .cornerRadius(Theme.Radius.sm)

                    if isEditing, let onDelete {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Text("Delete session")
                                .font(Theme.Font.body)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                        .stroke(Color.brand.border, lineWidth: 1)
                                )
                                .cornerRadius(Theme.Radius.sm)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, Theme.Space.sm)
                    }

                    Spacer(minLength: Theme.Space.lg)
                }
                .padding(Theme.Space.lg)
            }
            .background(Color.white)
            .navigationTitle(isEditing ? "Edit Session" : "Add Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(Theme.Font.link)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                        .font(Theme.Font.link)
                }
            }
        }
        // ✅ makes it feel like a “small editor”, not a whole page
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.Font.meta)
            .foregroundColor(Color.brand.textSecondary)
    }

    private func save() {
        let session = Session(
            id: existingSession?.id,
            userId: existingSession?.userId ?? block.userId,
            blockId: block.id ?? "",
            date: date,
            details: trimmedDetails,
            createdAt: existingSession?.createdAt ?? Date(),
            updatedAt: Date()
        )

        onSave(session)
        dismiss()
    }
}
