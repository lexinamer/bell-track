import SwiftUI

struct ColorTheme {
    let primary = Color("AccentColor")
    let background = Color("Background")
    let surface = Color("Surface")
    let textPrimary = Color("TextPrimary")
    let textSecondary = Color("TextSecondary")
    let border = Color("Border")

    // Additional semantic colors for dark mode
    let surfaceSecondary = Color(red: 0.15, green: 0.15, blue: 0.15)  // #262626
    let destructive = Color(red: 1.0, green: 0.27, blue: 0.23)        // #FF453A
    let success = Color(red: 0.20, green: 0.78, blue: 0.35)           // #32C759

    /// Single unified block color - bright purple for dark backgrounds
    static let blockColor = Color(red: 0.60, green: 0.60, blue: 1.0)  // #9999FF

    /// Color for workouts not assigned to any block
    static let unassignedWorkoutColor = Color(red: 0.67, green: 0.67, blue: 0.67)  // #AAAAAA
}

extension Color {
    static let brand = ColorTheme()
}
