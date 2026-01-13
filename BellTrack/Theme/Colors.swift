import SwiftUI

struct ColorTheme {
    let primary = Color("AccentColor")
    let background = Color("Background")
    let surface = Color("Surface")
    let textPrimary = Color("TextPrimary")     // #333
    let textSecondary = Color("TextSecondary") // #666
    let border = Color("Border")
}

extension Color {
    static let brand = ColorTheme()
}
