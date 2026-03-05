import SwiftUI

enum Theme {

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
    }

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let smp: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
    }

    enum TypeSize {
        static let xs: CGFloat = 12
        static let sm: CGFloat = 14
        static let md: CGFloat = 16
        static let lg: CGFloat = 18
        static let xl: CGFloat = 20
    }

    enum Font {
        static let pageTitle = SwiftUI.Font.system(size: TypeSize.lg, weight: .bold)
        static let sectionTitle = SwiftUI.Font.system(size: TypeSize.md, weight: .bold)
        static let cardTitle = SwiftUI.Font.system(size: TypeSize.lg, weight: .medium)
        static let cardCaption = SwiftUI.Font.system(size: TypeSize.sm, weight: .regular)
        static let formInput = SwiftUI.Font.system(size: TypeSize.md, weight: .regular)
    }
}
