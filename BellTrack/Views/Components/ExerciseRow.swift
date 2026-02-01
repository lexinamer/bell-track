import SwiftUI

struct ExerciseRow: View {
    let exercise: Exercise
    
    var body: some View {
        Text(exercise.displayString)
            .font(Theme.Font.body)
            .foregroundColor(Color.brand.textPrimary)
            .padding(Theme.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.brand.surface)
            .cornerRadius(Theme.Radius.md)
    }
}
