import SwiftUI

enum Theme {

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
    }

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let smp: CGFloat = 12
        static let md: CGFloat = 16
        static let mdp: CGFloat = 20
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }
    
    enum IconSize {
        static let sm: CGFloat = 16
        static let md: CGFloat = 24
        static let lg: CGFloat = 32
        static let xl: CGFloat = 40
    }
    
    enum TypeSize {
        static let xs: CGFloat = 10
        static let sm: CGFloat = 13
        static let md: CGFloat = 16
        static let lg: CGFloat = 18
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
        static let xxxl: CGFloat = 34
    }

    enum Font {
        // Page and navigation
        static let pageTitle = SwiftUI.Font.system(size: TypeSize.xxxl, weight: .bold)
        static let navigationTitle = SwiftUI.Font.system(size: TypeSize.lg, weight: .semibold)
        static let sectionTitle = SwiftUI.Font.system(size: TypeSize.md, weight: .bold)
        
        // Cards
        static let cardTitle = SwiftUI.Font.system(size: TypeSize.md, weight: .medium)
        static let cardSecondary = SwiftUI.Font.system(size: TypeSize.md, weight: .regular)
        static let cardCaption = SwiftUI.Font.system(size: TypeSize.sm, weight: .regular)
        
        // Forms
        static let formLabel = SwiftUI.Font.system(size: TypeSize.md, weight: .medium)
        static let formInput = SwiftUI.Font.system(size: TypeSize.md, weight: .regular)
        
        // UI elements
        static let buttonPrimary = SwiftUI.Font.system(size: TypeSize.md, weight: .medium)
        static let emptyStateTitle = SwiftUI.Font.system(size: TypeSize.lg, weight: .semibold)
        static let emptyStateDescription = SwiftUI.Font.system(size: TypeSize.md, weight: .regular)
    }
}
