import SwiftUI

struct WorkoutCard: View {

    let workout: Workout
    let exercises: [Exercise]
    let accentColor: Color
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    @State private var isExpanded: Bool = false

    init(
        workout: Workout,
        exercises: [Exercise] = [],
        accentColor: Color = Color.brand.primary,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.workout = workout
        self.exercises = exercises
        self.accentColor = accentColor
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    private var title: String {
        if let name = workout.name, !name.isEmpty { return name }
        return workout.logs.map { $0.exerciseName }.joined(separator: ", ")
    }

    private var totalVolume: Double {
        workout.logs.reduce(0.0) { total, log in
            let logVolume = log.sets.reduce(0.0) { sum, set in
                guard
                    let sets = set.sets,
                    sets > 0,
                    let repsString = set.reps,
                    let reps = Double(repsString),
                    let weightString = set.weight,
                    let baseWeight = Double(weightString)
                else { return sum }
                let weight = set.isDouble ? baseWeight * 2 : baseWeight
                return sum + Double(sets) * reps * weight
            }
            return total + logVolume
        }
    }

    private var subtitleText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let dateStr = formatter.string(from: workout.date)
        let vol = Int(totalVolume.rounded())
        return vol > 0 ? "\(dateStr) · \(vol) kg" : dateStr
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 0) {
                mainRow
                if isExpanded {
                    Divider()
                        .padding(.horizontal, Theme.Space.md)
                    expandedSection
                }
            }
        }
        .background(Color.brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
        }
        .contextMenu {
            if let onEdit {
                Button { onEdit() } label: {
                    Label("Edit", systemImage: "square.and.pencil")
                }
            }
            if let onDelete {
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var mainRow: some View {
        HStack(alignment: .center, spacing: Theme.Space.md) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(title)
                    .font(Theme.Font.sectionTitle)
                    .foregroundColor(Color.brand.textPrimary)
                Text(subtitleText)
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(Color.brand.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Theme.Space.md)
        .padding(.leading, Theme.Space.md)
        .padding(.trailing, Theme.Space.md)
    }

    private var expandedSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            ForEach(workout.logs) { log in
                exerciseRow(log)
            }
        }
        .padding(.top, Theme.Space.sm)
        .padding(.bottom, Theme.Space.md)
        .padding(.leading, Theme.Space.md + 8)
        .padding(.trailing, Theme.Space.md)
    }

    private func exerciseRow(_ log: WorkoutLog) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            ForEach(Array(log.sets.enumerated()), id: \.element.id) { index, set in
                let setsReps: String = {
                    guard let sets = set.sets, sets > 0, let reps = set.reps, !reps.isEmpty else { return "" }
                    return "\(sets)×\(reps)"
                }()
                let weight: String = {
                    guard let w = set.weight, !w.isEmpty else { return "—" }
                    return set.isDouble ? "2×\(w)kg" : "\(w)kg"
                }()
                HStack(spacing: 0) {
                    if index == 0 {
                        Text(log.exerciseName)
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(Color.brand.textPrimary)
                            .frame(maxWidth: 160, alignment: .leading)
                    } else {
                        Spacer().frame(maxWidth: 160)
                    }
                    Text(setsReps)
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(Color.brand.textSecondary)
                        .frame(width: 60, alignment: .leading)
                    Text(weight)
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(Color.brand.textSecondary)
                        .frame(width: 60, alignment: .leading)
                }
            }
        }
    }
}
