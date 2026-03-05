import SwiftUI

struct ColorTheme {
    let primary = Color("AccentColor")
    let background = Color("Background")
    let surface = Color("Surface")
    let textPrimary = Color("TextPrimary")
    let textSecondary = Color("TextSecondary")
    let success = Color("Success")
    let border = Color("Border")
    let destructive = Color("Destructive")
}

extension Color {
    static let brand = ColorTheme()
}
