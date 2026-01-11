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

    // MARK: - Derived (not stored)

    /// Complete the day AFTER endDate (end Feb 1 -> complete Feb 2)
    var isCompleted: Bool {
        guard let endDate else { return false }
        let cal = Calendar.current
        let endDay = cal.startOfDay(for: endDate)
        let today = cal.startOfDay(for: Date())
        return today > endDay
    }

    /// - If endDate exists: "X of Y weeks" while active, otherwise "Complete"
    /// - If no endDate: "Ongoing"
    var statusText: String {
        guard let endDate else { return "Ongoing" }
        return isCompleted ? "Complete" : weekProgressText(start: startDate, end: endDate)
    }

    /// Only for completed blocks
    var dateRangeText: String? {
        guard isCompleted else { return nil }
        return Self.formatDateRange(start: startDate, end: endDate)
    }

    private func weekProgressText(start: Date, end: Date) -> String {
        let cal = Calendar.current

        // inclusive range (start..end)
        let totalDays = max(1, (cal.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
        let totalWeeks = max(1, Int(ceil(Double(totalDays) / 7.0)))

        let elapsedDays = max(0, (cal.dateComponents([.day], from: start, to: Date()).day ?? 0))
        let currentWeek = min(totalWeeks, (elapsedDays / 7) + 1)

        return "\(currentWeek) of \(totalWeeks) weeks"
    }

    private static func formatDateRange(start: Date, end: Date?) -> String? {
        guard let end else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"

        let startText = formatter.string(from: start)
        let endText = formatter.string(from: end)
        let yearText = yearFormatter.string(from: end)

        return "\(startText)–\(endText) \(yearText)"
    }
}

// MARK: - Firestore mapping

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

        if let notes, !notes.isEmpty { data["notes"] = notes }
        if let endDate { data["endDate"] = Timestamp(date: endDate) }

        return data
    }
}
