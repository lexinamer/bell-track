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
            let exercise = exercises.first(where: { $0.id == log.exerciseId })
            guard exercise?.mode != .time else { return total }
            let logVolume = log.sets.reduce(0.0) { sum, set in
                guard
                    let weightString = set.weight,
                    let baseWeight = Double(weightString)
                else { return sum }
                let weight: Double
                if set.isDouble {
                    weight = baseWeight * 2
                } else if let offsetString = set.offsetWeight, let offsetWeight = Double(offsetString), !offsetString.isEmpty {
                    weight = baseWeight + offsetWeight
                } else {
                    weight = baseWeight
                }
                // AMRAP: rounds × reps × weight
                if workout.workoutType == .amrap {
                    let rounds = Double(set.sets ?? 0)
                    let reps = set.reps.flatMap { Double($0) } ?? 0
                    return sum + rounds * reps * weight
                }
                // Strict: sets × reps × weight
                let setCount = Double(set.sets ?? 1)
                guard
                    setCount > 0,
                    let repsString = set.reps,
                    let reps = Double(repsString)
                else { return sum }
                return sum + setCount * reps * weight
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

    private var amrapRounds: Int? {
        guard workout.workoutType == .amrap else { return nil }
        return workout.logs.first?.sets.first?.sets
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

            if let rounds = amrapRounds {
                Text("\(rounds) rounds")
                    .font(Theme.Font.cardBadge)
                    .foregroundColor(Color.brand.textSecondary)
            }
        }
        .padding(.vertical, Theme.Space.md)
        .padding(.leading, Theme.Space.md)
        .padding(.trailing, Theme.Space.md)
    }

    private var expandedSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            if workout.workoutType == .amrap {
                amrapExpandedRows
            } else {
                strictExpandedRows
            }
        }
        .padding(.top, Theme.Space.sm)
        .padding(.bottom, Theme.Space.md)
        .padding(.leading, Theme.Space.md + 8)
        .padding(.trailing, Theme.Space.md)
    }

    // MARK: - AMRAP expanded: rounds header + exercise · reps · weight

    private var amrapExpandedRows: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            ForEach(workout.logs) { log in
                let set = log.sets.first
                let rounds = set?.sets ?? 0
                let repsPerRound = set?.reps.flatMap { Int($0) } ?? 0
                let totalReps = rounds * repsPerRound
                let weight = amrapWeightStr(set)
                HStack(spacing: 0) {
                    Text(log.exerciseName)
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(Color.brand.textPrimary)
                        .frame(maxWidth: 160, alignment: .leading)
                    if totalReps > 0 {
                        Text("\(totalReps) reps")
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(Color.brand.textSecondary)
                            .frame(width: 60, alignment: .leading)
                    }
                    Text(weight)
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(Color.brand.textSecondary)
                        .frame(width: 60, alignment: .leading)
                }
            }
        }
    }

    private func amrapWeightStr(_ set: LogSet?) -> String {
        guard let set, let w = set.weight, !w.isEmpty else { return "—" }
        if set.isDouble { return "2×\(w)kg" }
        if let o = set.offsetWeight, !o.isEmpty { return "\(w)/\(o)kg" }
        return "\(w)kg"
    }

    // MARK: - Strict expanded: grouped sets×reps + weight

    private var strictExpandedRows: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            ForEach(workout.logs) { log in
                strictExerciseRow(log)
            }
        }
    }

    private func strictExerciseRow(_ log: WorkoutLog) -> some View {
        let mode = exercises.first(where: { $0.id == log.exerciseId })?.mode ?? .reps
        let rows = strictDisplayRows(for: log, mode: mode)
        return VStack(alignment: .leading, spacing: Theme.Space.xs) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 0) {
                    if index == 0 {
                        Text(log.exerciseName)
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(Color.brand.textPrimary)
                            .frame(maxWidth: 160, alignment: .leading)
                    } else {
                        Spacer().frame(maxWidth: 160)
                    }
                    Text(row.setsReps)
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(Color.brand.textSecondary)
                        .frame(width: 60, alignment: .leading)
                    Text(row.weight)
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(Color.brand.textSecondary)
                        .frame(width: 60, alignment: .leading)
                }
            }
        }
    }

    private func strictDisplayRows(for log: WorkoutLog, mode: ExerciseMode) -> [(setsReps: String, weight: String)] {
        func weightStr(_ set: LogSet) -> String {
            guard let w = set.weight, !w.isEmpty else { return "—" }
            if set.isDouble { return "2×\(w)kg" }
            if let o = set.offsetWeight, !o.isEmpty { return "\(w)/\(o)kg" }
            return "\(w)kg"
        }

        var groups: [(set: LogSet, count: Int)] = []
        for set in log.sets {
            if let last = groups.last,
               last.set.reps == set.reps,
               last.set.weight == set.weight,
               last.set.isDouble == set.isDouble,
               last.set.offsetWeight == set.offsetWeight {
                groups[groups.count - 1].count += 1
            } else {
                groups.append((set, 1))
            }
        }
        return groups.map { group in
            let setsReps: String = {
                guard let reps = group.set.reps, !reps.isEmpty else { return "" }
                return mode == .time ? "\(group.count)×\(reps)s" : "\(group.count)×\(reps)"
            }()
            return (setsReps, weightStr(group.set))
        }
    }
}
