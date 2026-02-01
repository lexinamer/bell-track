import SwiftUI

struct WorkoutCard: View {
    let workout: Workout
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(workout.dateString)
                .font(Theme.Font.headline)
                .foregroundColor(Color.brand.textPrimary)
            
            ForEach(workout.exercises) { exercise in
                Text(exercise.displayString)
                    .font(Theme.Font.body)
                    .foregroundColor(Color.brand.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.md)
        .background(Color.brand.surface)
        .cornerRadius(Theme.Radius.md)
    }
}
