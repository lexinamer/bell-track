import SwiftUI

struct BlockCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var name = ""
    @State private var selectedDuration: BlockDuration = .four
    @State private var workouts: [Workout] = [
        Workout(name: "A", exercises: [])
    ]
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brand.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.lg) {
                        nameSection
                        durationSection
                        workoutsSection
                    }
                    .padding(Theme.Space.md)
                }
            }
            .navigationTitle("New Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.brand.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveBlock()
                    }
                    .disabled(!canSave || isSaving)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("Block Name")
                .font(Theme.Font.meta)
                .foregroundColor(.brand.textSecondary)

            TextField("e.g., Strength Phase", text: $name)
                .font(Theme.Font.body)
                .padding(Theme.Space.md)
                .background(Color.brand.surface)
                .cornerRadius(Theme.Radius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .stroke(Color.brand.border, lineWidth: 1)
                )
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("Duration")
                .font(Theme.Font.meta)
                .foregroundColor(.brand.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.sm) {
                    ForEach(BlockDuration.allCases) { duration in
                        DurationChip(
                            duration: duration,
                            isSelected: selectedDuration == duration
                        ) {
                            selectedDuration = duration
                        }
                    }
                }
            }
        }
    }

    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text("Workouts")
                .font(Theme.Font.meta)
                .foregroundColor(.brand.textSecondary)

            ForEach($workouts) { $workout in
                WorkoutEditorCard(workout: $workout) {
                    if workouts.count > 1 {
                        workouts.removeAll { $0.id == workout.id }
                    }
                }
            }

            Button {
                let nextLetter = String(UnicodeScalar("A".unicodeScalars.first!.value + UInt32(workouts.count))!)
                workouts.append(Workout(name: nextLetter, exercises: []))
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Workout")
                }
                .font(Theme.Font.body)
                .foregroundColor(.brand.primary)
                .frame(maxWidth: .infinity)
                .padding(Theme.Space.md)
                .background(Color.brand.surface)
                .cornerRadius(Theme.Radius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .stroke(Color.brand.border, lineWidth: 1)
                )
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !workouts.isEmpty &&
        workouts.allSatisfy { !$0.exercises.isEmpty }
    }

    private func saveBlock() {
        guard let userId = appViewModel.userId else { return }

        isSaving = true

        let block = Block(
            userId: userId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: Date(),
            durationWeeks: selectedDuration.rawValue,
            workouts: workouts
        )

        Task {
            await appViewModel.saveBlock(block)
            dismiss()
        }
    }
}

struct DurationChip: View {
    let duration: BlockDuration
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(duration.displayName)
                .font(Theme.Font.meta)
                .foregroundColor(isSelected ? .white : .brand.textPrimary)
                .padding(.horizontal, Theme.Space.md)
                .padding(.vertical, Theme.Space.sm)
                .background(isSelected ? Color.brand.primary : Color.brand.surface)
                .cornerRadius(Theme.Radius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .stroke(isSelected ? Color.clear : Color.brand.border, lineWidth: 1)
                )
        }
    }
}
