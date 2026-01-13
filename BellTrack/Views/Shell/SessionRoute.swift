import Foundation

struct SessionRoute: Identifiable, Equatable {
    let id = UUID()
    let block: Block
    let session: Session? // nil = new, non-nil = edit
}
