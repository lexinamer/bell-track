import SwiftUI

// MARK: - Card Chrome (single source of truth)

enum CardChromeTokens {
    static let cornerRadius: CGFloat = CornerRadius.md

    // Shadow 1
    static let shadow1Color: Color = Color(hex: 0x323247, alpha: 0.10)
    static let shadow1X: CGFloat = 0
    static let shadow1Y: CGFloat = 1
    static let shadow1Blur: CGFloat = 3

    // Shadow 2
    static let shadow2Color: Color = Color(hex: 0x7A7A9D, alpha: 0.08)
    static let shadow2X: CGFloat = 0
    static let shadow2Y: CGFloat = 0
    static let shadow2Blur: CGFloat = 2
}

struct CardChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(
                    cornerRadius: CardChromeTokens.cornerRadius,
                    style: .continuous
                )
                .fill(Color.brand.surface)
            )
            .shadow(
                color: CardChromeTokens.shadow1Color,
                radius: CardChromeTokens.shadow1Blur,
                x: CardChromeTokens.shadow1X,
                y: CardChromeTokens.shadow1Y
            )
            .shadow(
                color: CardChromeTokens.shadow2Color,
                radius: CardChromeTokens.shadow2Blur,
                x: CardChromeTokens.shadow2X,
                y: CardChromeTokens.shadow2Y
            )
    }
}

extension View {
    func cardChrome() -> some View {
        modifier(CardChrome())
    }
}

private extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
