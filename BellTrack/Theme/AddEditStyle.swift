import SwiftUI

struct AddEditStyle {
    // Fonts
    static let titleFont = Font.system(size: Typography.xl, weight: .semibold)
    static let sectionLabelFont = Font.system(size: Typography.sm, weight: .semibold)
    static let helperLabelFont = Font.system(size: Typography.sm)
    static let fieldFont = Font.system(size: Typography.md)
    static let blockTitleFont = Font.system(size: Typography.md, weight: .bold)

    // Spacing
    static let sectionSpacing: CGFloat = Spacing.lg
    static let labelToFieldSpacing: CGFloat = Spacing.xs
    static let fieldStackSpacing: CGFloat = Spacing.md
    static let blockCardPadding: CGFloat = Spacing.xs

    // Misc
    static let trackIconSize: CGFloat = Typography.lg
}
