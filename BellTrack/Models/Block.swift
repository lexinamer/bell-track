import Foundation
import FirebaseFirestore

// MARK: - Block Duration

enum BlockDuration: Int, CaseIterable, Codable {
    case twoWeeks = 2
    case fourWeeks = 4
    case sixWeeks = 6
    case eightWeeks = 8
}

// MARK: - Block Model

struct Block: Identifiable {

    // MARK: - Stored Properties (REAL DATA)

    let id: String
    var name: String                 // MUST be var (HomeView renames blocks)
    let startDate: Date
    let duration: BlockDuration

    // MARK: - App Init

    init(
        id: String = UUID().uuidString,
        name: String,
        startDate: Date,
        duration: BlockDuration
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.duration = duration
    }

    // MARK: - Firestore Init

    init?(from document: DocumentSnapshot) {
        let data = document.data() ?? [:]

        guard
            let name = data["name"] as? String,
            let startTimestamp = data["startDate"] as? Timestamp,
            let durationRaw = data["duration"] as? Int,
            let duration = BlockDuration(rawValue: durationRaw)
        else {
            return nil
        }

        self.id = document.documentID
        self.name = name
        self.startDate = startTimestamp.dateValue()
        self.duration = duration
    }

    // MARK: - Firestore Encoding

    var firestoreData: [String: Any] {
        [
            "name": name,
            "startDate": Timestamp(date: startDate),
            "duration": duration.rawValue
        ]
    }
}

// MARK: - Computed Properties (USED BY HOMEVIEW)

extension Block {

    /// Text shown under the block title on HomeView
    var statusText: String {
        "Active"
    }

    /// Date range text shown on HomeView
    var dateRangeText: String {
        let endDate = Calendar.current.date(
            byAdding: .weekOfYear,
            value: duration.rawValue,
            to: startDate
        ) ?? startDate

        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }

    /// Compile-time property only.
    /// HomeView expects this to exist, real workouts come from AppViewModel.
    var workouts: [Workout] {
        []
    }
}
