import Foundation

struct WorkoutListSpacing {
    // Each element's bottom spacing
    static let dateBottom: CGFloat = 0  // Date → Note
    static let dateBottomNoNote: CGFloat = 0  // Date → Block (no note)
    static let noteBottom: CGFloat = 0  // Note → First Block
    static let blockBottom: CGFloat = 0  // Block → Next Block
    static let lastBlockBottom: CGFloat = 0  // Last Block → Divider
    static let dividerBottom: CGFloat = 0  // Divider → Next Date
    
    // Block internal spacing
    static let blockLineSpacing: CGFloat = 0  // Between exercise line and details
    
    // Note internal padding
    static let noteVerticalPadding: CGFloat = 0
    static let noteHorizontalPadding: CGFloat = 0
    
    // Horizontal padding
    static let horizontalPadding: CGFloat = Spacing.lg
}
