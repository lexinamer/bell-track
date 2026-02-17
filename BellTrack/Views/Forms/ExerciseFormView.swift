import SwiftUI

struct ExerciseFormView: View {
    let exercise: Exercise?
    let onSave: (String, [MuscleGroup], [MuscleGroup], ExerciseMode) -> Void
    let onCancel: () -> Void

    @State private var nameInput: String
    @State private var primaryMuscles: [MuscleGroup]
    @State private var secondaryMuscles: [MuscleGroup]
    @State private var mode: ExerciseMode

    init(
        exercise: Exercise? = nil,
        onSave: @escaping (String, [MuscleGroup], [MuscleGroup], ExerciseMode) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.exercise = exercise
        self.onSave = onSave
        self.onCancel = onCancel
        self._nameInput = State(initialValue: exercise?.name ?? "")
        self._primaryMuscles = State(initialValue: exercise?.primaryMuscles ?? [])
        self._secondaryMuscles = State(initialValue: exercise?.secondaryMuscles ?? [])
        self._mode = State(initialValue: exercise?.mode ?? .reps)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Exercise name", text: $nameInput)
                        .autocorrectionDisabled()
                }

                Section("Tracking Mode") {
                    Picker("Mode", selection: $mode) {
                        Text("Reps").tag(ExerciseMode.reps)
                        Text("Time").tag(ExerciseMode.time)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Primary Muscles") {
                    muscleChips(
                        selected: $primaryMuscles,
                        excluded: secondaryMuscles
                    )
                }

                Section("Secondary Muscles") {
                    muscleChips(
                        selected: $secondaryMuscles,
                        excluded: primaryMuscles
                    )
                }
            }
            .navigationTitle(exercise == nil ? "New Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(nameInput, primaryMuscles, secondaryMuscles, mode)
                    }
                    .disabled(
                        nameInput.trimmingCharacters(in: .whitespaces).isEmpty ||
                        primaryMuscles.isEmpty
                    )
                }
            }
        }
    }

    // MARK: - Muscle Chips

    private func muscleChips(
        selected: Binding<[MuscleGroup]>,
        excluded: [MuscleGroup]
    ) -> some View {
        let available = MuscleGroup.allCases.filter { !excluded.contains($0) }

        return WrappingHStack(items: available) { muscle in
            muscleChip(muscle: muscle, selected: selected)
        }
    }

    private func muscleChip(muscle: MuscleGroup, selected: Binding<[MuscleGroup]>) -> some View {
        let isSelected = selected.wrappedValue.contains(muscle)

        return Button {
            if isSelected {
                selected.wrappedValue.removeAll { $0 == muscle }
            } else {
                selected.wrappedValue.append(muscle)
            }
        } label: {
            Text(muscle.displayName)
                .font(Theme.Font.cardCaption)
                .padding(.horizontal, 12)
                .padding(.vertical, Theme.Space.xs)
                .background(isSelected ? Color.brand.primary : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Wrapping HStack

struct WrappingHStack<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0

        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                content(item)
                    .padding(.trailing, Theme.Space.xs)
                    .padding(.bottom, Theme.Space.xs)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > geometry.size.width {
                            width = 0
                            height -= d.height + 6
                        }
                        let result = width
                        if item == items.last {
                            width = 0
                        } else {
                            width -= d.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item == items.last {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .background(viewHeightReader($totalHeight))
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geometry in
            Color.clear.preference(
                key: HeightPreferenceKey.self,
                value: geometry.size.height
            )
        }
        .onPreferenceChange(HeightPreferenceKey.self) { height in
            binding.wrappedValue = height
        }
    }
}

private struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
