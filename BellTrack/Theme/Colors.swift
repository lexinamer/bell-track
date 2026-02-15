import SwiftUI

struct ColorTheme {
    let primary = Color("AccentColor")
    let background = Color("Background")
    let surface = Color("Surface")
    let surfaceSecondary = Color("SurfaceSecondary")
    let textPrimary = Color("TextPrimary")
    let textSecondary = Color("TextSecondary")
    let border = Color("Border")
    let destructive = Color("Destructive")
    let success = Color("Success")
    let blockColor = Color("BlockColor")
}

extension Color {
    static let brand = ColorTheme()
}
