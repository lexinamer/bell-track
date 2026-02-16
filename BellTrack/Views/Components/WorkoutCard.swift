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
    let onDelete: (() -> Void)?

    // MARK: - Init

    init(
        workout: Workout,
        isExpanded: Binding<Bool>? = nil,
        badgeColor: Color? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.workout = workout
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
        externalBadgeColor ?? Color.brand.blockColor
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
            let weight = Double(log.weight ?? "0") ?? 0
            return total + (sets * reps * weight)
        }
    }

    private var exerciseCountText: String {
        return "\(workout.logs.count) exercise\(workout.logs.count == 1 ? "" : "s")"
    }

    private var volumeText: String {
        guard totalVolume > 0 else { return "" }
        return "Volume: \(String(format: "%.0f", totalVolume)) lbs"
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
        .background(Color.brand.surfaceSecondary)
        .cornerRadius(Theme.Radius.md)
        .shadow(
            color: Color.black.opacity(0.25),
            radius: 8,
            x: 0,
            y: 2
        )
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

                HStack(spacing: Theme.Space.sm) {
                    if !volumeText.isEmpty {
                        Text(volumeText)
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(Color.brand.textSecondary)

                        Text("•")
                            .font(Theme.Font.cardSecondary)
                            .foregroundColor(Color.brand.textSecondary)
                    }

                    Text(exerciseCountText)
                        .font(Theme.Font.cardSecondary)
                        .foregroundColor(Color.brand.textSecondary)
                }
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

            Text(workout.date, format: .dateTime.day())
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text(workout.date, format: .dateTime.month(.abbreviated))
                .font(.system(size: 11, weight: .medium))
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
            spacing: Theme.Space.md
        ) {

            ForEach(workout.logs) { log in
                exerciseRow(log)
            }
        }
        .padding(Theme.Space.md)
    }

    private func exerciseRow(_ log: WorkoutLog) -> some View {

        VStack(alignment: .leading, spacing: Theme.Space.xs) {

            Text(log.exerciseName)
                .font(Theme.Font.cardTitle)
                .foregroundColor(Color.brand.textPrimary)

            HStack(spacing: Theme.Space.sm) {
                if let sets = log.sets, sets > 0 {
                    detailChip(text: "\(sets) sets")
                }

                if let reps = log.reps, !reps.isEmpty {
                    let label = log.mode == .time ? "sec" : "reps"
                    detailChip(text: "\(reps) \(label)")
                }

                if let weight = log.weight, !weight.isEmpty {
                    let displayWeight = log.isDouble ? "2×\(weight)kg" : "\(weight)kg"
                    detailChip(text: displayWeight)
                }
            }

            if let note = log.note, !note.isEmpty {
                Text(note)
                    .font(Theme.Font.cardCaption)
                    .foregroundColor(Color.brand.textSecondary)
                    .padding(.top, Theme.Space.xs)
            }
        }
        .padding(Theme.Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brand.background)
        .cornerRadius(Theme.Radius.sm)
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
