import Foundation
import FirebaseFirestore

struct Block: Identifiable, Codable, Equatable {

    var id: String?
    var userId: String

    var name: String
    var notes: String?

    var startDate: Date
    var endDate: Date?

    var createdAt: Date
    var updatedAt: Date

    init(
        id: String? = nil,
        userId: String,
        name: String,
        notes: String? = nil,
        startDate: Date,
        endDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isCompleted: Bool {
        guard let endDate else { return false }
        let cal = Calendar.current
        let endDay = cal.startOfDay(for: endDate)
        let today = cal.startOfDay(for: Date())
        return today > endDay
    }

    var isActive: Bool { !isCompleted }
}

extension Block {

    init?(from doc: DocumentSnapshot) {
        guard
            let data = doc.data(),
            let userId = data["userId"] as? String,
            let name = data["name"] as? String,
            let startTimestamp = data["startDate"] as? Timestamp
        else { return nil }

        self.init(
            id: doc.documentID,
            userId: userId,
            name: name,
            notes: data["notes"] as? String,
            startDate: startTimestamp.dateValue(),
            endDate: (data["endDate"] as? Timestamp)?.dateValue(),
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? startTimestamp.dateValue(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "name": name,
            "startDate": Timestamp(date: startDate),
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: Date())
        ]

        if let notes, !notes.isEmpty {
            data["notes"] = notes
        }

        if let endDate {
            data["endDate"] = Timestamp(date: endDate)
        }

        return data
    }
}

extension Block {

    var fullDateRangeText: String {
        let start = startDate.formatted(.dateTime.month(.abbreviated).day().year())
        guard let endDate else { return start }
        let end = endDate.formatted(.dateTime.month(.abbreviated).day().year())
        return "\(start) – \(end)"
    }
}
