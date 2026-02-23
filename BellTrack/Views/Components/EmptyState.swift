import SwiftUI

struct EmptyState: View {

    let showBlockStep: Bool
    let showTemplateStep: Bool
    let showWorkoutStep: Bool

    let workoutAction: (() -> Void)?
    let createTemplateAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {

            if showBlockStep {
                stepRow(
                    title: "Block created",
                    complete: showTemplateStep || showWorkoutStep
                )
            }

            if showTemplateStep {
                stepRow(
                    title: showWorkoutStep ? "Template created" : "Create a workout template",
                    complete: showWorkoutStep,
                    action: showWorkoutStep ? nil : workoutAction
                )
            }

            if showWorkoutStep {
                if let createTemplateAction {
                    stepRow(
                        title: "Create another template",
                        complete: false,
                        action: createTemplateAction
                    )
                }
                
                stepRow(
                    title: "Log your first workout",
                    complete: false,
                    action: workoutAction
                )
            }
        }
        .padding(.top, Theme.Space.lg)
        .padding(.horizontal, Theme.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stepRow(
        title: String,
        complete: Bool,
        action: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: Theme.Space.sm) {

            Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                .font(Theme.Font.cardCaption)
                .foregroundColor(
                    complete
                    ? Color.brand.success
                    : Color.brand.textSecondary.opacity(0.4)
                )

            if let action, !complete {
                Button(action: action) {
                    Text(title)
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(Color.brand.textPrimary)
                }
                .buttonStyle(.plain)
            } else {
                Text(title)
                    .font(Theme.Font.cardSecondary)
                    .foregroundColor(
                        complete
                        ? Color.brand.textSecondary
                        : Color.brand.textPrimary
                    )
            }
        }
    }
}

extension EmptyState {

    static func noActiveBlock(action: @escaping () -> Void) -> EmptyState {
        EmptyState(
            showBlockStep: true,
            showTemplateStep: false,
            showWorkoutStep: false,
            workoutAction: action,
            createTemplateAction: nil
        )
    }

    static func noTemplates(action: @escaping () -> Void) -> EmptyState {
        EmptyState(
            showBlockStep: true,
            showTemplateStep: true,
            showWorkoutStep: false,
            workoutAction: action,
            createTemplateAction: nil
        )
    }

    static func noWorkouts(
        logAction: @escaping () -> Void,
        createTemplateAction: @escaping () -> Void
    ) -> EmptyState {
        EmptyState(
            showBlockStep: true,
            showTemplateStep: true,
            showWorkoutStep: true,
            workoutAction: logAction,
            createTemplateAction: createTemplateAction
        )
    }
}
