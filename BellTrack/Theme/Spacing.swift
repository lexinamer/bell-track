import Foundation

struct Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 40
}
//
//struct WorkoutListSpacing {
//    // Each element's bottom spacing
//    static let dateBottom: CGFloat = Spacing.sm  // Date → Note
//    static let dateBottomNoNote: CGFloat = Spacing.sm  // Date → Block (no note)
//    static let noteBottom: CGFloat = Spacing.sm  // Note → First Block
//    static let blockBottom: CGFloat = Spacing.sm  // Block → Next Block
//    static let lastBlockBottom: CGFloat = Spacing.md  // Last Block → Divider
//    static let dividerBottom: CGFloat = Spacing.md  // Divider → Next Date
//    
//    // Block internal spacing
//    static let blockLineSpacing: CGFloat = Spacing.xs  // Between exercise line and details
//    
//    // Note internal padding
//    static let noteVerticalPadding: CGFloat = Spacing.sm
//    
//    // Horizontal padding
//    static let horizontalPadding: CGFloat = Spacing.lg
//}

struct WorkoutListSpacing {
    // Each element's bottom spacing
    static let dateBottom: CGFloat = 0  // Date → Note
    static let dateBottomNoNote: CGFloat = 0  // Date → Block (no note)
    static let noteBottom: CGFloat = 0  // Note → First Block
    static let blockBottom: CGFloat = 0  // Block → Next Block
    static let lastBlockBottom: CGFloat = Spacing.md  // Last Block → Divider (keep some space before divider)
    static let dividerBottom: CGFloat = Spacing.lg  // Divider → Next Date (keep space between days)
    
    // Block internal spacing
    static let blockLineSpacing: CGFloat = Spacing.xs  // Between exercise line and details (keep this)
    
    // Note internal padding
    static let noteVerticalPadding: CGFloat = 0
    
    // Horizontal padding
    static let horizontalPadding: CGFloat = Spacing.lg
}
