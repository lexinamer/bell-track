import SwiftUI

struct ColorTheme {
    let primary = Color("BrandPrimary")
    let background = Color("Background")
    let surface = Color("Surface")
    let textPrimary = Color("TextPrimary")
    let textSecondary = Color("TextSecondary")
    let border = Color("Border")
    let destructive = Color("Destructive")
    let success = Color("Success")
}

extension Color {
    static let brand = ColorTheme()
}
