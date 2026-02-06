import SwiftUI

struct BlockFormView: View {
    let block: Block?
    let onSave: (String, Date, BlockType, Int?, String?, Int?) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var startDate: Date
    @State private var isDuration: Bool
    @State private var durationWeeks: Int?
    @State private var notes: String
    @State private var colorIndex: Int

    init(
        block: Block? = nil,
        onSave: @escaping (String, Date, BlockType, Int?, String?, Int?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.block = block
        self.onSave = onSave
        self.onCancel = onCancel

        self._name = State(initialValue: block?.name ?? "")
        self._startDate = State(initialValue: block?.startDate ?? Date())
        self._isDuration = State(initialValue: block?.type == .duration)
        self._durationWeeks = State(initialValue: block?.durationWeeks)
        self._notes = State(initialValue: block?.notes ?? "")
        self._colorIndex = State(initialValue: block?.colorIndex ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Block name", text: $name)
                        .autocorrectionDisabled()

                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)

                    Toggle("Duration block", isOn: $isDuration)

                    if isDuration {
                        HStack {
                            Text("Duration")
                            Spacer()
                            TextField("Weeks", value: $durationWeeks, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }
                }

                Section("Goal") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }

                Section("Color") {
                    HStack(spacing: Theme.Space.md) {
                        ForEach(0..<ColorTheme.blockPalette.count, id: \.self) { idx in
                            Circle()
                                .fill(ColorTheme.blockPalette[idx])
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.primary, lineWidth: colorIndex == idx ? 2.5 : 0)
                                )
                                .onTapGesture {
                                    colorIndex = idx
                                }
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle(block == nil ? "New Block" : "Edit Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let blockType: BlockType = isDuration ? .duration : .ongoing
                        let finalNotes = notes.trimmingCharacters(in: .whitespaces)
                        onSave(name, startDate, blockType, durationWeeks, finalNotes.isEmpty ? nil : finalNotes, colorIndex)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty ||
                             (isDuration && (durationWeeks == nil || durationWeeks! <= 0)))
                }
            }
        }
    }
}
