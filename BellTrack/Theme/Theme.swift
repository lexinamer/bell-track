import SwiftUI

enum Theme {

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
    }

    enum TypeSize {
        static let sm: CGFloat = 13
        static let md: CGFloat = 15
        static let lg: CGFloat = 17
        static let xl: CGFloat = 20
    }

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Font {
        static let title = SwiftUI.Font.system(size: TypeSize.xl, weight: .semibold)
        static let bodyStrong  = SwiftUI.Font.system(size: TypeSize.md, weight: .semibold)
        static let body  = SwiftUI.Font.system(size: TypeSize.md, weight: .regular)
        static let meta  = SwiftUI.Font.system(size: TypeSize.sm, weight: .regular)
        static let link  = SwiftUI.Font.system(size: TypeSize.sm, weight: .semibold)
    }
}
