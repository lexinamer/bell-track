import SwiftUI

struct EmptyState: View {
    let title: String
    let message: String
    let buttonTitle: String?
    let action: (() -> Void)?

    init(
        title: String,
        message: String,
        buttonTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: Theme.Space.lg) {

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
                        .foregroundColor(Color.brand.textPrimary)
                        .cornerRadius(Theme.Radius.md)
                }
                .padding(.horizontal, Theme.Space.xl)
            }
        }
        .padding(.horizontal, Theme.Space.md)
    }
}

extension EmptyState {

    static func noActiveBlock(action: @escaping () -> Void) -> EmptyState {
        EmptyState(
            title: "Blocks organize your training",
            message: "Create a block to add templates and log workouts",
            buttonTitle: "Create Block",
            action: action
        )
    }

    static func noTemplates(action: @escaping () -> Void) -> EmptyState {
        EmptyState(
            title: "Templates define your workouts",
            message: "Create a template to log workouts and track progress",
            buttonTitle: "Create Template",
            action: action
        )
    }

    static func noWorkouts(action: @escaping () -> Void) -> EmptyState {
        EmptyState(
            title: "Workouts track your progress",
            message: "Log a workout using a template",
            buttonTitle: "Log Workout",
            action: action
        )
    }
}
