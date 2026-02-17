import SwiftUI

struct WorkoutCard: View {

    let workout: Workout
    let exercises: [Exercise]

    // Optional external expansion control
    private let externalExpanded: Binding<Bool>?

    // Optional external color override
    private let externalBadgeColor: Color?

    // Internal expansion state fallback
    @State private var internalExpanded: Bool = false

    // Optional actions
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    // MARK: - Init

    init(
        workout: Workout,
        exercises: [Exercise] = [],
        isExpanded: Binding<Bool>? = nil,
        badgeColor: Color? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.workout = workout
        self.exercises = exercises
        self.externalExpanded = isExpanded
        self.externalBadgeColor = badgeColor
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    // MARK: - Expansion State

    private var isExpanded: Bool {
        externalExpanded?.wrappedValue ?? internalExpanded
    }

    private func toggleExpanded() {

        if let externalExpanded {
            externalExpanded.wrappedValue.toggle()
        } else {
            internalExpanded.toggle()
        }
    }

    // MARK: - Derived

    private var badgeColor: Color {
        externalBadgeColor ?? Color.brand.primary
    }

    private var title: String {

        if let name = workout.name, !name.isEmpty {
            return name
        }

        return workout.logs
            .map { $0.exerciseName }
            .joined(separator: ", ")
    }

    private var totalSets: Int {

        workout.logs
            .compactMap { $0.sets }
            .reduce(0, +)
    }

    private var totalVolume: Double {
        workout.logs.reduce(0.0) { total, log in
            let sets = Double(log.sets ?? 0)
            let reps = Double(log.reps ?? "0") ?? 0
            let baseWeight = Double(log.weight ?? "0") ?? 0
            let weight = log.isDouble ? baseWeight * 2 : baseWeight

            // Look up exercise mode
            let exercise = exercises.first(where: { $0.id == log.exerciseId })
            let mode = exercise?.mode ?? .reps

            // Only count rep-based weighted exercises for real volume
            // Exclude time-based exercises (they skew the metric)
            if weight > 0 && reps > 0 && mode != .time {
                return total + (sets * reps * weight)
            } else {
                return total
            }
        }
    }

    private var metadataText: String {
        let volumeValue = Int(totalVolume.rounded())
        let repCount = workout.logs.reduce(0) { total, log in
            total + ((Int(log.reps ?? "0") ?? 0) * (log.sets ?? 0))
        }

        if volumeValue > 0 {
            return "\(volumeValue) kg • \(repCount) reps"
        } else {
            return "\(repCount) reps"
        }
    }

    // MARK: - View

    var body: some View {

        VStack(alignment: .leading, spacing: 0) {

            mainRow

            if isExpanded {

                Divider()
                    .padding(.horizontal, Theme.Space.md)

                expandedSection
            }
        }
        .background(Color.brand.surface)
        .cornerRadius(Theme.Radius.md)
        .contentShape(Rectangle())
    }

    // MARK: - Main Row

    private var mainRow: some View {

        HStack(
            alignment: .top,
            spacing: Theme.Space.md
        ) {

            dateBadge

            VStack(
                alignment: .leading,
                spacing: Theme.Space.xs
            ) {

                Text(title)
                    .font(Theme.Font.cardTitle)
                    .foregroundColor(Color.brand.textPrimary)

                Text(metadataText)
                    .font(Theme.Font.cardSecondary)
                    .foregroundColor(Color.brand.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    toggleExpanded()
                }
            }

            Spacer(minLength: 0)

            if onEdit != nil || onDelete != nil {
                Menu {
                    if let onEdit {
                        Button {
                            onEdit()
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }

                    if let onDelete {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(Color.brand.textSecondary)
                        .frame(width: 32, height: 32)
                }
            }
        }
        .padding(Theme.Space.md)
    }

    // MARK: - Date Badge

    private var dateBadge: some View {
        VStack(spacing: 2) {
            Text(workout.date, format: .dateTime.month(.abbreviated))
                .font(Theme.Font.cardCaption)
                .foregroundColor(.white)

            Text(workout.date, format: .dateTime.day())
                .font(Theme.Font.navigationTitle)
                .foregroundColor(.white)
        }
        .frame(width: 44, height: 44)
        .background(badgeColor)
        .cornerRadius(Theme.Radius.sm)
    }

    // MARK: - Expanded Section

    private var expandedSection: some View {

        VStack(
            alignment: .leading,
            spacing: Theme.Space.md
        ) {

            ForEach(workout.logs) { log in
                exerciseRow(log)
            }
        }
        .padding(Theme.Space.md)
    }

    private func exerciseRow(_ log: WorkoutLog) -> some View {
        exerciseRowContent(log)
    }

    private func exerciseRowContent(_ log: WorkoutLog) -> some View {
        let exercise = exercises.first(where: { $0.id == log.exerciseId })
        let mode = exercise?.mode ?? .reps

        return VStack(alignment: .leading, spacing: Theme.Space.xs) {
            HStack(spacing: Theme.Space.md) {
                // Exercise name
                Text(log.exerciseName)
                    .font(Theme.Font.cardTitle)
                    .foregroundColor(Color.brand.textPrimary)
                    .frame(minWidth: 120, alignment: .leading)

                // Sets × Reps or Sets × Time
                if let sets = log.sets, sets > 0, let reps = log.reps, !reps.isEmpty {
                    let repsDisplay = mode == .time ? ":\(reps)" : reps
                    Text("\(sets)×\(repsDisplay)")
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(Color.brand.textSecondary)
                        .frame(minWidth: 50, alignment: .leading)
                }

                // Weight
                if let weight = log.weight, !weight.isEmpty {
                    let displayWeight = log.isDouble ? "2×\(weight)kg" : "\(weight)kg"
                    Text(displayWeight)
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(Color.brand.textSecondary)
                }

                Spacer()
            }

            if let note = log.note, !note.isEmpty {
                Text(note)
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(Color.brand.textSecondary)
                    .padding(.top, Theme.Space.xs)
            }
        }
    }

    private func detailChip(text: String) -> some View {
        Text(text)
            .font(Theme.Font.cardCaption)
            .foregroundColor(Color.brand.textSecondary)
            .padding(.horizontal, Theme.Space.sm)
            .padding(.vertical, 4)
            .background(Color.brand.surface)
            .cornerRadius(Theme.Radius.sm)
    }
}
