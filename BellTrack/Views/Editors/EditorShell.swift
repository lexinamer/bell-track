import SwiftUI

/// Shared wrapper for your editors so Block + Session screens feel consistent.
/// Keeps the "X" close button, centered title, and trailing Save button.
struct EditorShell<Content: View>: View {

    let title: String
    let canSave: Bool
    let onSave: () -> Void

    @ViewBuilder let content: () -> Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {
                    content()
                }
                .padding(Theme.Space.lg)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.brand.textPrimary)
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(Theme.Font.title)
                        .foregroundColor(Color.brand.textPrimary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(!canSave)
                    .font(Theme.Font.link)
                }
            }
        }
    }
}

// MARK: - Small helpers used across editors

extension View {
    /// Consistent field label styling for editor screens.
    func editorFieldLabelStyle() -> some View {
        self
            .font(Theme.Font.meta)
            .foregroundColor(Color.brand.textSecondary)
    }
}
