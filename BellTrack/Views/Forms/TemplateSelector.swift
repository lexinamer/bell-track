import SwiftUI

struct TemplateSelector: View {

    let templates: [(template: WorkoutTemplate, blockName: String)]
    let onSelect: (WorkoutTemplate) -> Void
    let onCancel: () -> Void

    var body: some View {

        NavigationStack {
            ZStack {
                Color.brand.background
                    .ignoresSafeArea()

                if templates.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(templates, id: \.template.id) { item in
                            Button {
                                onSelect(item.template)
                            } label: {
                                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                                    Text(item.template.name)
                                        .font(Theme.Font.cardTitle)
                                        .foregroundColor(Color.brand.textPrimary)

                                    Text(item.blockName)
                                        .font(Theme.Font.cardCaption)
                                        .foregroundColor(Color.brand.textSecondary)
                                }
                                .padding(.vertical, Theme.Space.xs)
                            }
                            .listRowBackground(Color.brand.surface)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Select Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Space.md) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 44))
                .foregroundColor(Color.brand.textSecondary)

            Text("No templates available")
                .font(Theme.Font.emptyStateTitle)
                .foregroundColor(Color.brand.textPrimary)

            Text("Create templates in your active blocks first.")
                .font(Theme.Font.emptyStateDescription)
                .foregroundColor(Color.brand.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Space.xl)
        }
    }
}
