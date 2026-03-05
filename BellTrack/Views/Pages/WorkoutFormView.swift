import SwiftUI

struct WorkoutFormView: View {

    let entry: WorkoutEntry?
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    @State private var segments: [String]

    private let firestore = FirestoreService.shared

    init(entry: WorkoutEntry?) {
        self.entry = entry
        _date = State(initialValue: entry?.date ?? Date())
        _segments = State(initialValue: entry?.segments ?? [""])
    }

    private var isValid: Bool {
        segments.contains { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brand.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.md) {

                        // Date
                        VStack(alignment: .leading, spacing: Theme.Space.xs) {
                            Text("Date")
                                .font(Theme.Font.cardCaption)
                                .foregroundColor(Color.brand.textSecondary)
                                .padding(.horizontal, Theme.Space.sm)

                            DatePicker("Select date", selection: $date, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .padding(Theme.Space.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.brand.surface)
                                .cornerRadius(Theme.Radius.md)
                        }

                        // Segments
                        VStack(alignment: .leading, spacing: Theme.Space.xs) {
                            Text("Segments")
                                .font(Theme.Font.cardCaption)
                                .foregroundColor(Color.brand.textSecondary)
                                .padding(.horizontal, Theme.Space.sm)

                            VStack(spacing: Theme.Space.sm) {
                                ForEach(Array(segments.enumerated()), id: \.offset) { index, _ in
                                    HStack(spacing: Theme.Space.sm) {
                                        TextField("e.g. ABC 5×5 (2x16)", text: $segments[index])
                                            .font(Theme.Font.formInput)
                                            .foregroundColor(Color.brand.textPrimary)
                                            .padding(Theme.Space.md)
                                            .background(Color.brand.surface)
                                            .cornerRadius(Theme.Radius.md)

                                        if segments.count > 1 {
                                            Button {
                                                segments.remove(at: index)
                                            } label: {
                                                Image(systemName: "minus.circle.fill")
                                                    .foregroundColor(Color.brand.destructive)
                                                    .font(.system(size: 22))
                                            }
                                        }
                                    }
                                }
                            }

                            Button {
                                segments.append("")
                            } label: {
                                HStack(spacing: Theme.Space.xs) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add segment")
                                }
                                .font(Theme.Font.cardCaption)
                                .foregroundColor(Color.brand.primary)
                            }
                            .padding(.top, Theme.Space.xs)
                            .padding(.horizontal, Theme.Space.sm)
                        }
                    }
                    .padding(Theme.Space.md)
                }
            }
            .navigationTitle(entry == nil ? "Log Workout" : "Edit Workout")
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

    // MARK: - Save

    private func save() async {
        let updated = WorkoutEntry(
            id: entry?.id ?? UUID().uuidString,
            date: date,
            segments: segments.filter { !$0.isEmpty }
        )
        try? await firestore.saveWorkout(updated)
    }
}
