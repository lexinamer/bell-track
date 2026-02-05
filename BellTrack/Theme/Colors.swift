import SwiftUI

struct ColorTheme {
    let primary = Color("AccentColor")
    let background = Color("Background")
    let surface = Color("Surface")
    let textPrimary = Color("TextPrimary")     // #333
    let textSecondary = Color("TextSecondary") // #666
    let border = Color("Border")

    /// Purple shades for blocks — each block picks one via colorIndex
    static let blockPalette: [Color] = [
        Color(red: 0.42, green: 0.16, blue: 0.71),  // deep purple (close to AccentColor)
        Color(red: 0.31, green: 0.22, blue: 0.72),  // indigo-purple
        Color(red: 0.55, green: 0.24, blue: 0.78),  // medium purple
        Color(red: 0.38, green: 0.10, blue: 0.55),  // dark plum
        Color(red: 0.60, green: 0.40, blue: 0.80),  // soft lavender-purple
        Color(red: 0.25, green: 0.12, blue: 0.50),  // very dark purple
    ]

    /// Color for workouts not assigned to any block
    static let unassignedWorkoutColor = Color(red: 0.55, green: 0.55, blue: 0.62)

    static func blockColor(for colorIndex: Int?) -> Color {
        guard let idx = colorIndex, idx >= 0, idx < blockPalette.count else {
            return blockPalette[0]
        }
        return blockPalette[idx]
    }
}

extension Color {
    static let brand = ColorTheme()
}
