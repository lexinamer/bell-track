import Foundation
import FirebaseFirestore

struct Session: Identifiable, Codable, Equatable {

    var id: String?
    var userId: String
    var blockId: String

    var date: Date
    var details: String?

    var createdAt: Date
    var updatedAt: Date

    init(
        id: String? = nil,
        userId: String,
        blockId: String,
        date: Date,
        details: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.blockId = blockId
        self.date = date
        self.details = details
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var trimmedDetails: String? {
        let t = (details ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    var hasDetails: Bool { trimmedDetails != nil }
}

extension Session {

    init?(from doc: DocumentSnapshot) {
        guard
            let data = doc.data(),
            let userId = data["userId"] as? String,
            let blockId = data["blockId"] as? String,
            let dateTimestamp = data["date"] as? Timestamp
        else { return nil }

        self.init(
            id: doc.documentID,
            userId: userId,
            blockId: blockId,
            date: dateTimestamp.dateValue(),
            details: data["details"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? dateTimestamp.dateValue(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "blockId": blockId,
            "date": Timestamp(date: date),
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: Date())
        ]

        if let t = trimmedDetails {
            data["details"] = t
        }

        return data
    }
}
