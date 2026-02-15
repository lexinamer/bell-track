import SwiftUI

struct WorkoutCard: View {

    let workout: Workout

    // Optional external expansion control
    private let externalExpanded: Binding<Bool>?

    // Optional external color override
    private let externalBadgeColor: Color?

    // Internal expansion state fallback
    @State private var internalExpanded: Bool = false

    // Optional actions
    let onEdit: (() -> Void)?
    let onDuplicate: (() -> Void)?
    let onDelete: (() -> Void)?

    // MARK: - Init

    init(
        workout: Workout,
        isExpanded: Binding<Bool>? = nil,
        badgeColor: Color? = nil,
        onEdit: (() -> Void)? = nil,
        onDuplicate: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.workout = workout
        self.externalExpanded = isExpanded
        self.externalBadgeColor = badgeColor
        self.onEdit = onEdit
        self.onDuplicate = onDuplicate
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
        externalBadgeColor ?? ColorTheme.unassignedWorkoutColor
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

    private var exerciseCountText: String {

        "\(workout.logs.count) exercise\(workout.logs.count == 1 ? "" : "s") • \(totalSets) sets"
    }

    // MARK: - View

    var body: some View {

        VStack(alignment: .leading, spacing: 0) {

            mainRow

            if isExpanded {

                Divider()
                    .padding(.horizontal)

                expandedSection
            }
        }
        .background(Color.brand.surface)
        .cornerRadius(Theme.Radius.md)
        .shadow(
            color: Color.black.opacity(0.25),
            radius: 8,
            x: 0,
            y: 2
        )
        .contentShape(Rectangle())
        .contextMenu { contextMenu }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenu: some View {

        if let onEdit {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
        }

        if let onDuplicate {
            Button(action: onDuplicate) {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
        }

        if let onDelete {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
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

                Text(exerciseCountText)
                    .font(Theme.Font.cardSecondary)
                    .foregroundColor(Color.brand.textSecondary)
            }

            Spacer()
        }
        .padding(Theme.Space.md)
        .contentShape(Rectangle())
        .onTapGesture {

            withAnimation(.easeInOut(duration: 0.2)) {
                toggleExpanded()
            }
        }
    }

    // MARK: - Date Badge

    private var dateBadge: some View {

        VStack(spacing: 2) {

            Text(workout.date, format: .dateTime.day())
                .font(Theme.Font.navigationTitle)
                .foregroundColor(.white)

            Text(workout.date, format: .dateTime.month(.abbreviated))
                .font(Theme.Font.cardCaption)
                .foregroundColor(.white)
        }
        .frame(width: 50, height: 50)
        .background(badgeColor)
        .cornerRadius(Theme.Radius.sm)
    }

    // MARK: - Expanded Section

    private var expandedSection: some View {

        VStack(
            alignment: .leading,
            spacing: Theme.Space.sm
        ) {

            ForEach(workout.logs) { log in
                exerciseRow(log)
            }
        }
        .padding(Theme.Space.md)
        .background(Color.brand.background)
    }

    private func exerciseRow(_ log: WorkoutLog) -> some View {

        Text(formatExerciseDetails(log))
            .font(Theme.Font.cardSecondary)
            .foregroundColor(Color.brand.textPrimary)
    }

    // MARK: - Formatting

    private func formatExerciseDetails(
        _ log: WorkoutLog
    ) -> String {

        var parts: [String] = []

        parts.append(log.exerciseName)

        if let sets = log.sets {

            if let reps = log.reps, !reps.isEmpty {
                parts.append("\(sets)x\(reps)")
            } else {
                parts.append("\(sets) sets")
            }
        }

        if let weight = log.weight, !weight.isEmpty {
            parts.append("\(weight)kg")
        }

        if let note = log.note, !note.isEmpty {
            parts.append(note)
        }

        return parts.joined(separator: " • ")
    }
}
