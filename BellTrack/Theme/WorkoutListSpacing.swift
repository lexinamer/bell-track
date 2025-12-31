import Foundation

struct WorkoutListSpacing {
    // Each element's bottom spacing
    static let dateBottom: CGFloat = 6  // Date → Note
    static let dateBottomNoNote: CGFloat = 10  // Date → Block (no note)
    static let noteBottom: CGFloat = 8  // Note → First Block
    static let blockBottom: CGFloat = 10  // Block → Next Block
    static let lastBlockBottom: CGFloat = 14  // Last Block → Divider
    static let dividerBottom: CGFloat = 20  // Divider → Next Date
    
    // Block internal spacing
    static let blockLineSpacing: CGFloat = 2  // Between exercise line and details
    
    // Note internal padding
    static let noteVerticalPadding: CGFloat = 6
    static let noteHorizontalPadding: CGFloat = Spacing.lg
    
    // Horizontal padding
    static let horizontalPadding: CGFloat = Spacing.lg
}
