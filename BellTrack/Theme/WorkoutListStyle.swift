import SwiftUI

struct WorkoutListStyle {
    // Fonts
    static let dateFont = Font.system(size: Typography.lg, weight: .bold)
    static let noteFont = Font.system(size: Typography.sm, weight: .regular)
    static let blockTitleFont = Font.system(size: Typography.md, weight: .medium)
    static let blockDetailsFont = Font.system(size: Typography.sm, weight: .regular)
    
    //Spacing
        // Date → note / first block
        static let dateBottom: CGFloat = Spacing.md
        static let dateBottomNoNote: CGFloat = Spacing.md

        // Note → first block
        static let noteBottom: CGFloat = Spacing.lg

        // Block → next block
        static let blockBottom: CGFloat = Spacing.md

        // Last block → divider
        static let lastBlockBottom: CGFloat = Spacing.lg
        static let dividerBottom: CGFloat = Spacing.lg

        // Inside a block: title → metric/details
        static let blockLineSpacing: CGFloat = Spacing.xs

        // Note padding (inside the note text itself)
        static let noteVerticalPadding: CGFloat = 0
        static let noteHorizontalPadding: CGFloat = 0

        // Left/right inset of all content
        static let horizontalPadding: CGFloat = Spacing.lg
}
