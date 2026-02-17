import SwiftUI

struct EmptyState: View {
    let icon: String
    let title: String
    let message: String
    let buttonTitle: String?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        message: String,
        buttonTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: Theme.Space.lg) {
            Spacer()

            Image(systemName: icon)
                .font(Theme.Font.pageTitle)
                .foregroundColor(Color.brand.textSecondary)

            Text(title)
                .font(Theme.Font.emptyStateTitle)
                .foregroundColor(Color.brand.textPrimary)

            Text(message)
                .font(Theme.Font.emptyStateDescription)
                .foregroundColor(Color.brand.textSecondary)
                .multilineTextAlignment(.center)

            if let buttonTitle = buttonTitle, let action = action {
                Button {
                    action()
                } label: {
                    Text(buttonTitle)
                        .font(Theme.Font.buttonPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Space.sm)
                        .background(Color.brand.primary)
                        .foregroundColor(Color.brand.background)
                        .cornerRadius(Theme.Radius.md)
                }
                .padding(.horizontal, Theme.Space.xl)
            }

            Spacer()
        }
    }
}

extension EmptyState {
    static func noActiveBlock(action: @escaping () -> Void) -> EmptyState {
        EmptyState(
            icon: "square.stack.3d.up",
            title: "No active block",
            message: "Create a block to start training",
            buttonTitle: "Create Block",
            action: action
        )
    }

    static var noWorkouts: EmptyState {
        EmptyState(
            icon: "figure.run",
            title: "No workouts yet",
            message: "Log your first workout to get started"
        )
    }
}
