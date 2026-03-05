import SwiftUI

struct WorkoutFormView: View {

    let entry: WorkoutEntry
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    @State private var segments: [String]

    private let firestore = FirestoreService.shared
    private let isNew: Bool

    init(entry: WorkoutEntry) {
        self.entry = entry
        self.isNew = entry.segments.isEmpty
        _date = State(initialValue: entry.date)
        _segments = State(initialValue: entry.segments.isEmpty ? [""] : entry.segments)
    }

    private var isValid: Bool {
        segments.contains { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Date") {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }

                Section("Exercises") {
                    ForEach(Array(segments.enumerated()), id: \.offset) { index, _ in
                        HStack(spacing: Theme.Space.sm) {
                            TextField("e.g. ABC 5×5 @ 2x16", text: $segments[index])
                                .font(Theme.Font.formInput)
                            if segments.count > 1 {
                                Button {
                                    segments.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(Color.brand.destructive)
                                        .font(.system(size: Theme.TypeSize.lg))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Button {
                        segments.append("")
                    } label: {
                        HStack(spacing: Theme.Space.xs) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add exercise")
                        }
                        .font(Theme.Font.cardCaption)
                        .foregroundColor(Color.brand.primary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.brand.background)
            .navigationTitle(isNew ? "Log Workout" : "Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.brand.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save(); dismiss() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
                }
            }
        }
    }

    private func save() async {
        let updated = WorkoutEntry(
            id: entry.id,
            date: date,
            segments: segments.filter { !$0.isEmpty }
        )
        try? await firestore.saveWorkout(updated)
    }
}
