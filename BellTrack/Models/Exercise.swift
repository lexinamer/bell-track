import Foundation

struct Exercise: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var trackingType: TrackingType

    init(id: String = UUID().uuidString, name: String, trackingType: TrackingType = .weightReps) {
        self.id = id
        self.name = name
        self.trackingType = trackingType
    }

    var firestoreData: [String: Any] {
        [
            "id": id,
            "name": name,
            "trackingType": trackingType.rawValue
        ]
    }

    init?(from data: [String: Any]) {
        guard
            let id = data["id"] as? String,
            let name = data["name"] as? String,
            let trackingTypeRaw = data["trackingType"] as? String,
            let trackingType = TrackingType(rawValue: trackingTypeRaw)
        else { return nil }

        self.id = id
        self.name = name
        self.trackingType = trackingType
    }
}
