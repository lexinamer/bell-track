import SwiftUI

// MARK: - No Active Block (full-screen centered style)

struct EmptyStateNoActiveBlock: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: Theme.Space.lg) {
            Spacer()

            VStack(spacing: Theme.Space.xs) {
                Text("No active block")
                    .font(Theme.Font.emptyStateTitle)
                    .foregroundColor(Color.brand.textPrimary)
                Text("Create a block to organize your training.")
                    .font(Theme.Font.emptyStateDescription)
                    .foregroundColor(Color.brand.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: action) {
                Text("Create Block")
                    .font(Theme.Font.buttonPrimary)
                    .foregroundColor(.white)
                    .padding(.horizontal, Theme.Space.xl)
                    .padding(.vertical, Theme.Space.smp)
                    .background(Color.brand.primary)
                    .clipShape(Capsule())
            }

            Spacer()
        }
    }
}

// MARK: - No Workouts (inline style for block detail)

struct EmptyStateNoWorkouts: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: Theme.Space.lg) {
            Spacer().frame(height: Theme.Space.xl)

            VStack(spacing: Theme.Space.xs) {
                Text("No workouts yet")
                    .font(Theme.Font.cardTitle)
                    .foregroundColor(Color.brand.textPrimary)
                Text("Log your first workout to get started.")
                    .font(Theme.Font.cardSecondary)
                    .foregroundColor(Color.brand.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: action) {
                Text("Log Workout")
                    .font(Theme.Font.buttonPrimary)
                    .foregroundColor(.white)
                    .padding(.horizontal, Theme.Space.xl)
                    .padding(.vertical, Theme.Space.smp)
                    .background(Color.brand.primary)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, Theme.Space.md)
        .frame(maxWidth: .infinity)
    }
}
