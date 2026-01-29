import Foundation

struct Exercise: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var trackingTypes: [TrackingType]

    init(
        id: String = UUID().uuidString,
        name: String,
        trackingTypes: [TrackingType]
    ) {
        self.id = id
        self.name = name
        self.trackingTypes = trackingTypes
    }
}
