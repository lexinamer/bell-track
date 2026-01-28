import Foundation
import FirebaseFirestore

enum BlockDuration: Int, CaseIterable, Identifiable {
    case one = 1
    case two = 2
    case four = 4
    case six = 6
    case eight = 8
    case ten = 10

    var id: Int { rawValue }

    var displayName: String {
        "\(rawValue) week\(rawValue == 1 ? "" : "s")"
    }
}

struct Block: Identifiable, Codable, Equatable {
    var id: String?
    var userId: String
    var name: String
    var startDate: Date
    var durationWeeks: Int
    var workouts: [Workout]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String? = nil,
        userId: String,
        name: String,
        startDate: Date = Date(),
        durationWeeks: Int = 4,
        workouts: [Workout] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.startDate = startDate
        self.durationWeeks = durationWeeks
        self.workouts = workouts
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var endDate: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: durationWeeks, to: startDate) ?? startDate
    }

    var isCompleted: Bool {
        Date() > endDate
    }

    var isActive: Bool { !isCompleted }

    var weeksRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekOfYear], from: Date(), to: endDate)
        return max(0, components.weekOfYear ?? 0)
    }

    var currentWeek: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekOfYear], from: startDate, to: Date())
        return min(durationWeeks, max(1, (components.weekOfYear ?? 0) + 1))
    }
}

extension Block {
    init?(from doc: DocumentSnapshot) {
        guard
            let data = doc.data(),
            let userId = data["userId"] as? String,
            let name = data["name"] as? String,
            let startTimestamp = data["startDate"] as? Timestamp,
            let durationWeeks = data["durationWeeks"] as? Int
        else { return nil }

        var workouts: [Workout] = []
        if let workoutsData = data["workouts"] as? [[String: Any]] {
            workouts = workoutsData.compactMap(Workout.init(from:))
        }

        self.init(
            id: doc.documentID,
            userId: userId,
            name: name,
            startDate: startTimestamp.dateValue(),
            durationWeeks: durationWeeks,
            workouts: workouts,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? startTimestamp.dateValue(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    var firestoreData: [String: Any] {
        [
            "userId": userId,
            "name": name,
            "startDate": Timestamp(date: startDate),
            "durationWeeks": durationWeeks,
            "workouts": workouts.map { $0.firestoreData },
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: Date())
        ]
    }
}

extension Block {
    var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: startDate)
        let end = formatter.string(from: endDate)
        return "\(start) – \(end)"
    }

    var statusText: String {
        if isCompleted {
            return "Completed"
        } else {
            return "Week \(currentWeek) of \(durationWeeks)"
        }
    }
}
