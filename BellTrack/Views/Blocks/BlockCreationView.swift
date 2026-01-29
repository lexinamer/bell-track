import SwiftUI

struct BlockCreationView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var name = ""
    @State private var startDate = Date()
    @State private var duration: BlockDuration = .fourWeeks

    let onSave: (Block) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Block Info")) {
                    TextField("Block Name", text: $name)

                    DatePicker(
                        "Start Date",
                        selection: $startDate,
                        displayedComponents: .date
                    )
                }

                Section(header: Text("Duration")) {
                    Picker("Duration", selection: $duration) {
                        ForEach(BlockDuration.allCases, id: \.self) { value in
                            Text("\(value.rawValue) weeks")
                                .tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Create Block")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let block = Block(
                            name: name,
                            startDate: startDate,
                            duration: duration
                        )
                        Task {
                            await appViewModel.saveBlock(block)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
