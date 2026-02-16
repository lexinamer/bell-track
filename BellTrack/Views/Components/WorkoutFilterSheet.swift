import SwiftUI

struct WorkoutFilterSheet: View {

    @Environment(\.dismiss) var dismiss

    let templates: [WorkoutTemplate]
    let selectedTemplateId: String?
    let onSelectTemplate: (String?) -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // All Workouts Option
                filterOption(
                    title: "All Workouts",
                    isSelected: selectedTemplateId == nil
                ) {
                    onSelectTemplate(nil)
                    dismiss()
                }

                Divider()
                    .padding(.leading, Theme.Space.md)

                // Template Options
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(templates) { template in
                            filterOption(
                                title: template.name,
                                isSelected: selectedTemplateId == template.id
                            ) {
                                onSelectTemplate(template.id)
                                dismiss()
                            }

                            if template.id != templates.last?.id {
                                Divider()
                                    .padding(.leading, Theme.Space.md)
                            }
                        }
                    }
                }
            }
            .background(Color.brand.background)
            .navigationTitle("Filter Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color.brand.primary)
                }
            }
        }
    }

    private func filterOption(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(Theme.Font.cardTitle)
                    .foregroundColor(Color.brand.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.brand.primary)
                }
            }
            .padding(Theme.Space.md)
            .background(Color.brand.background)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
