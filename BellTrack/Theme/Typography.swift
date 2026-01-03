import SwiftUI

struct Typography {
    static let xs: CGFloat = 12
    static let sm: CGFloat = 14
    static let md: CGFloat = 16
    static let lg: CGFloat = 18
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
}

struct TextStyles {
    static let title = Font.system(size: Typography.xl, weight: .bold)
    static let heading = Font.system(size: Typography.md, weight: .semibold)
    static let bodyStrong = Font.system(size: Typography.md, weight: .medium)
    static let body = Font.system(size: Typography.md, weight: .regular)
    static let subtext = Font.system(size: Typography.sm, weight: .regular)
    static let subtextStrong = Font.system(size: Typography.sm, weight: .medium)
    static let caption = Font.system(size: Typography.xs, weight: .regular)
}
