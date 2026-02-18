import SwiftUI

struct TemplateFilterChips: View {
    let blockIndex: Int
    let templates: [WorkoutTemplate]
    let selectedTemplateId: String?
    let onSelect: (String?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.sm) {
                ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                    let isSelected = selectedTemplateId == template.id

                    FilterChip(
                        title: template.name,
                        isSelected: isSelected,
                        color: BlockColorPalette.templateColor(
                            blockIndex: blockIndex,
                            templateIndex: index
                        ),
                        action: {
                            if isSelected {
                                onSelect(nil)
                            } else {
                                onSelect(template.id)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, Theme.Space.sm)
                .padding(.vertical, 6)
                .background(color)
                .cornerRadius(Theme.Radius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .inset(by: 0.75)
                        .stroke(.white, lineWidth: isSelected ? 1.5 : 0)
                )
        }
    }
}
