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
            let sets   = Double(log.sets ?? 0)
            let reps   = Double(log.reps ?? "0") ?? 0
            let base   = Double(log.weight ?? "0") ?? 0
            let weight = log.isDouble ? base * 2 : base
            let mode   = exercises.first(where: { $0.id == log.exerciseId })?.mode ?? .reps
            return (weight > 0 && reps > 0 && mode != .time) ? total + sets * reps * weight : total
        }
    }

    private var totalReps: Int {
        workout.logs.reduce(0) { total, log in
            let sets = log.sets ?? 0
            let reps = Int(log.reps ?? "0") ?? 0
            return total + sets * reps
        }
    }

    private var subtitleText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let dateStr = formatter.string(from: workout.date)
        let vol = Int(totalVolume.rounded())
        if vol > 0 { return "\(dateStr) · \(vol) kg" }
        let reps = totalReps
        if reps > 0 { return "\(dateStr) · \(reps) reps" }
        return dateStr
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
                    Label("Edit", systemImage: "pencil")
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
                    .font(Theme.Font.cardTitle)
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
        VStack(alignment: .leading, spacing: Theme.Space.md) {
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
        let exercise = exercises.first(where: { $0.id == log.exerciseId })
        let mode = exercise?.mode ?? .reps

        return HStack(spacing: 0) {
            Text(log.exerciseName)
                .font(Theme.Font.sectionTitle)
                .foregroundColor(Color.brand.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let sets = log.sets, sets > 0, let reps = log.reps, !reps.isEmpty {
                let display = mode == .time ? ":\(reps)" : reps
                Text("\(sets)×\(display)")
                    .font(Theme.Font.cardSecondary)
                    .foregroundColor(Color.brand.textSecondary)
                    .frame(width: 70, alignment: .trailing)
            }

            if let weight = log.weight, !weight.isEmpty {
                Text(log.isDouble ? "2×\(weight)kg" : "\(weight)kg")
                    .font(Theme.Font.cardSecondary)
                    .foregroundColor(Color.brand.textSecondary)
                    .frame(width: 70, alignment: .trailing)
            }
        }
    }
}
