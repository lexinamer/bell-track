import Foundation

struct Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 40
}

struct CardStyle {
    static let cardHorizontalPadding: CGFloat = Spacing.md
    static let cardVerticalPadding: CGFloat = cardTopBottomPadding
    static let cardTopBottomPadding: CGFloat = Spacing.lg
    static let dateToFirstBlock: CGFloat = -8
    static let blockLineSpacing: CGFloat = Spacing.xs
    static let sectionSpacing: CGFloat = Spacing.md
    static let bottomSpacer: CGFloat = Spacing.sm
}

struct AddEditStyle {
    static let labelToFieldSpacing: CGFloat = Spacing.xs
    static let fieldStackSpacing: CGFloat = Spacing.md
    static let blockCardPadding: CGFloat = Spacing.sm
    static let outerSectionSpacing: CGFloat = 0
    static let movementFieldGroupSpacing: CGFloat = Spacing.md
}
