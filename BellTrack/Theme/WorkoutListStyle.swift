import SwiftUI


//struct WorkoutListStyle {
//    // Spacing
//    static let dateBottom: CGFloat = Spacing.sm
//    static let dateBottomNoNote: CGFloat = Spacing.sm
//    static let blockLineSpacing: CGFloat = Spacing.xs
//    static let noteBottom: CGFloat = Spacing.lg
//    static let blockBottom: CGFloat = Spacing.md
//    static let lastBlockBottom: CGFloat = Spacing.md
//    static let dividerBottom: CGFloat = Spacing.md
//    static let noteVerticalPadding: CGFloat = 0
//    static let noteHorizontalPadding: CGFloat = 0
//    static let horizontalPadding: CGFloat = Spacing.lg
//}

struct WorkoutListStyle {
    // Fonts
    static let dateFont = Font.system(size: Typography.lg, weight: .bold)
    static let noteFont = Font.system(size: Typography.sm, weight: .regular)
    static let blockTitleFont = Font.system(size: Typography.md, weight: .semibold)
    static let blockDetailsFont = Font.system(size: Typography.sm, weight: .regular)
    
    //Spacing
//        // Date → note / first block
//        static let dateBottom: CGFloat = 12
//        static let dateBottomNoNote: CGFloat = 12
//
//        // Note → first block
//        static let noteBottom: CGFloat = 20
//
//        // Block → next block
//        static let blockBottom: CGFloat = 20
//
//        // Last block → divider
//        static let lastBlockBottom: CGFloat = 12
//        static let dividerBottom: CGFloat = 12
//
//        // Inside a block: title → metric/details
//        static let blockLineSpacing: CGFloat = 4
//
//        // Note padding (inside the note text itself)
//        static let noteVerticalPadding: CGFloat = 0
//        static let noteHorizontalPadding: CGFloat = 0
//
//        // Left/right inset of all content
//        static let horizontalPadding: CGFloat = Spacing.lg
    
    
    //Spacing
        // Date → note / first block
        static let dateBottom: CGFloat = Spacing.md
        static let dateBottomNoNote: CGFloat = Spacing.sm

        // Note → first block
        static let noteBottom: CGFloat = Spacing.lg

        // Block → next block
        static let blockBottom: CGFloat = Spacing.md

        // Last block → divider
        static let lastBlockBottom: CGFloat = Spacing.md
        static let dividerBottom: CGFloat = Spacing.md

        // Inside a block: title → metric/details
        static let blockLineSpacing: CGFloat = Spacing.xs

        // Note padding (inside the note text itself)
        static let noteVerticalPadding: CGFloat = 0
        static let noteHorizontalPadding: CGFloat = 0

        // Left/right inset of all content
        static let horizontalPadding: CGFloat = Spacing.lg
}

