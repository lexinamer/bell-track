import Foundation
import Combine

final class HomeViewModel: ObservableObject {

    @Published var blocks: [Block] = []
    @Published var sessionsByBlockId: [String: [Session]] = [:]
    @Published var isLoading: Bool = false
    @Published var filter: BlockFilter = .active

    private let firestore: FirestoreService

    init(firestore: FirestoreService = FirestoreService()) {
        self.firestore = firestore
    }

    var filteredBlocks: [Block] {
        switch filter {
        case .active:
            return blocks.filter { !$0.isCompleted }
        case .completed:
            return blocks.filter { $0.isCompleted }
        }
    }

    func sessions(for block: Block) -> [Session] {
        let id = block.id ?? ""
        return (sessionsByBlockId[id] ?? []).sorted { $0.date > $1.date }
    }

    func mostRecentSession(for block: Block) -> Session? {
        sessions(for: block).first
    }

    func makePrefilledNewSession(userId: String, block: Block) -> Session {
        Session(
            id: nil,
            userId: userId,
            blockId: block.id ?? "",
            date: Date(),
            details: mostRecentSession(for: block)?.details,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func load(userId: String) async {
        guard !userId.isEmpty else { return }
        await MainActor.run { self.isLoading = true }

        do {
            let fetchedBlocks = try await firestore.fetchBlocks(userId: userId)

            var map: [String: [Session]] = [:]
            for block in fetchedBlocks {
                guard let blockId = block.id else { continue }
                map[blockId] = try await firestore.fetchSessions(userId: userId, blockId: blockId)
            }

            await MainActor.run {
                self.blocks = fetchedBlocks
                self.sessionsByBlockId = map
                self.isLoading = false
            }
        } catch {
            await MainActor.run { self.isLoading = false }
        }
    }

    func saveBlock(userId: String, block: Block) async {
        guard !userId.isEmpty else { return }
        do {
            try await firestore.saveBlock(userId: userId, block: block)
            await load(userId: userId)
        } catch {}
    }

    func deleteBlock(userId: String, block: Block) async {
        guard !userId.isEmpty else { return }
        guard let blockId = block.id else { return }
        do {
            try await firestore.deleteBlock(userId: userId, blockId: blockId)
            await load(userId: userId)
        } catch {}
    }

    func completeBlock(userId: String, block: Block) async {
        var updated = block
        updated.endDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        await saveBlock(userId: userId, block: updated)
    }

    func saveSession(userId: String, session: Session) async {
        guard !userId.isEmpty else { return }
        do {
            try await firestore.saveSession(userId: userId, session: session)
            await load(userId: userId)
        } catch {}
    }

    func deleteSession(userId: String, session: Session) async {
        guard !userId.isEmpty else { return }
        guard let sessionId = session.id else { return }

        do {
            try await firestore.deleteSession(
                userId: userId,
                blockId: session.blockId,
                sessionId: sessionId
            )
            await load(userId: userId)
        } catch {}
    }
}
