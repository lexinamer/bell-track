import SwiftUI

struct Typography {
    static let sm: CGFloat = 12
    static let md: CGFloat = 14
    static let lg: CGFloat = 16
    static let xl: CGFloat = 18
}

struct TextStyles {

    // Navigation
    static let title = Font.system(size: Typography.xl, weight: .bold)

    // Cards
    static let cardTitle = Font.system(size: Typography.lg, weight: .semibold)
    static let cardMeta = Font.system(size: Typography.md, weight: .regular)

    // Content
    static let body = Font.system(size: Typography.lg, weight: .regular)
    static let bodySmall = Font.system(size: Typography.md, weight: .regular)

    // Actions / links
    static let link = Font.system(size: Typography.lg, weight: .semibold)
    static let linkSmall = Font.system(size: Typography.md, weight: .semibold)

    // Micro / badges / helper
    static let micro = Font.system(size: Typography.sm, weight: .regular)
}
