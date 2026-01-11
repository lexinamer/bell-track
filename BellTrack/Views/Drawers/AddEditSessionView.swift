import SwiftUI
import FirebaseAuth

struct AddEditSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService

    private let firestoreService = FirestoreService()

    let block: Block
    let existingSession: Session?
    let onSave: (Session) -> Void

    @State private var date: Date
    @State private var details: String

    private var isEditing: Bool {
        guard let id = existingSession?.id else { return false }
        return !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var navTitle: String { isEditing ? "Edit Session" : "Log Session" }

    init(
        block: Block,
        session: Session? = nil,
        onSave: @escaping (Session) -> Void
    ) {
        self.block = block
        self.existingSession = session
        self.onSave = onSave

        _date = State(initialValue: session?.date ?? Date())
        _details = State(initialValue: session?.details ?? "")
    }

    private var trimmedDetails: String? {
        let t = details.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private var canSave: Bool {
        // keep your rule: require details
        !(trimmedDetails?.isEmpty ?? true)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brand.surface.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Layout.sectionSpacing) {

                        FormDateField(label: "Date", date: $date)

                        VStack(alignment: .leading, spacing: Layout.contentSpacing) {
                            FormLabel(text: "Details")
                            FormTextEditor(
                                placeholder: "Notes, weights, reps, time, etc.",
                                text: $details
                            )
                        }
                    }
                    .padding(.horizontal, Layout.horizontalSpacing)
                    .padding(.vertical, Layout.listSpacing)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
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
                        Task { await saveAndDismiss() }
                    }
                }
            }
        }
    }

    // MARK: - Save

    private func saveAndDismiss() async {
        guard let userId = authService.user?.uid else { return }
        guard let blockId = block.id else { return }

        // If editing, keep id. If new/duplicate, generate a new id.
        let id = (isEditing ? existingSession?.id : nil) ?? UUID().uuidString

        // If duplicate, createdAt should be "now" (not the original session’s).
        let createdAt = isEditing ? (existingSession?.createdAt ?? Date()) : Date()

        let updated = Session(
            id: id,
            userId: userId,
            blockId: blockId,
            date: date,
            details: trimmedDetails,
            createdAt: createdAt,
            updatedAt: Date()
        )

        do {
            try await firestoreService.saveSession(userId: userId, session: updated)
            await MainActor.run {
                onSave(updated)
                dismiss()
            }
        } catch {
            // v1: fail quietly
        }
    }
}
