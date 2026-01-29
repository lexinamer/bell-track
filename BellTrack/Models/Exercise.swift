import Foundation

struct Exercise: Identifiable {

    // MARK: - Stored Properties

    let id: String
    let name: String
    let trackingTypes: [TrackingType]

    // MARK: - App Init

    init(
        id: String = UUID().uuidString,
        name: String,
        trackingTypes: [TrackingType]
    ) {
        self.id = id
        self.name = name
        self.trackingTypes = trackingTypes
    }

    // MARK: - Firestore Init

    init?(from data: [String: Any]) {
        guard
            let id = data["id"] as? String,
            let name = data["name"] as? String,
            let rawTypes = data["trackingTypes"] as? [String]
        else {
            return nil
        }

        let types = rawTypes.compactMap { TrackingType(rawValue: $0) }
        guard !types.isEmpty else { return nil }

        self.id = id
        self.name = name
        self.trackingTypes = types
    }

    // MARK: - Firestore Encoding

    var firestoreData: [String: Any] {
        [
            "id": id,
            "name": name,
            "trackingTypes": trackingTypes.map { $0.rawValue }
        ]
    }
}
