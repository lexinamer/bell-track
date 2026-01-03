import Foundation

struct Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 40
}

struct WorkoutListStyle {
    static let cardHorizontalPadding: CGFloat = Spacing.md
    static let cardTopBottomPadding: CGFloat = Spacing.lg
    static let dateToFirstBlock: CGFloat = Spacing.sm
    static let betweenBlocks: CGFloat = Spacing.md
    static let blockLineSpacing: CGFloat = Spacing.xs
}

struct AddEditStyle {
    static let sectionSpacing: CGFloat = Spacing.sm
    static let labelToFieldSpacing: CGFloat = Spacing.xs
    static let fieldStackSpacing: CGFloat = Spacing.md
    static let blockCardPadding: CGFloat = Spacing.xs
}
