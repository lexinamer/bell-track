import SwiftUI

extension Color {
    static let brand = ColorTheme()
}

struct ColorTheme {
    let primary = Color(hex: "7C3AED")
    let secondary = Color(hex: "3C029F")
    let background = Color(hex: "F5F5F5")
    let surface = Color(hex: "FFFFFF")
    let textPrimary = Color(hex: "333333")
    let textSecondary = Color(hex: "666666")
    let border = Color(hex: "E0E0E0")
    let destructive = Color(hex: "DC2626")
    let success = Color(hex: "16A34A")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
