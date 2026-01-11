import SwiftUI

struct BlockCardCompleted: View {
    let block: Block
    let statusLine: String
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            BlockCardContainer {
                BlockCardHeader(title: block.name) {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityHidden(true)
                }

                BlockCardSubline(text: statusLine)
            }
        }
        .buttonStyle(.plain)
    }
}
