import SwiftUI

struct TemplateFilterChips: View {
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
                        color: templateColor(index: index),
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

    private func templateColor(index: Int) -> Color {
        let colors = [
            Color(hex: "A64DFF"),
            Color(hex: "962EFF"),
            Color(hex: "8000FF"),
            Color(hex: "6900D1")
        ]
        return colors[index % colors.count]
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
                .font(Theme.Font.cardSecondary)
                .foregroundColor(.white)
                .padding(.horizontal, Theme.Space.md)
                .padding(.vertical, 8)
                .background(color)
                .cornerRadius(Theme.Radius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .inset(by: 0.5)
                        .stroke(.white.opacity(0.8), lineWidth: isSelected ? 1.5 : 0)
                )
        }
    }
}

extension TemplateFilterChips {
    static func templateColor(for index: Int) -> Color {
        let colors = [
            Color(hex: "A64DFF"),
            Color(hex: "962EFF"),
            Color(hex: "8000FF"),
            Color(hex: "6900D1")
        ]
        return colors[index % colors.count]
    }
}
