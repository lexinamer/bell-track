import SwiftUI

struct SimpleCard<Content: View>: View {

    let content: Content
    let onTap: (() -> Void)?

    init(
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.onTap = onTap
        self.content = content()
    }

    var body: some View {

        VStack(alignment: .leading, spacing: Theme.Space.md) {
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(Theme.Radius.md)
        .shadow(
            color: .black.opacity(0.05),
            radius: 2,
            x: 0,
            y: 1
        )
        .modifier(CardTapModifier(onTap: onTap))
    }
}

// MARK: - Tap modifier that DOES NOT break buttons

private struct CardTapModifier: ViewModifier {

    let onTap: (() -> Void)?

    func body(content: Content) -> some View {

        if let onTap {
            content
                .contentShape(Rectangle())
                .simultaneousGesture(
                    TapGesture().onEnded {
                        onTap()
                    }
                )
        } else {
            content
        }
    }
}
