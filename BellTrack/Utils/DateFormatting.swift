import Foundation

extension Date {

    /// Formats date as "MMM d" (e.g. "Jan 15")
    var shortDateString: String {
        formatted(.dateTime.month(.abbreviated).day())
    }

    /// Formats date as "MMM d, yyyy" (e.g. "Jan 15, 2026")
    var mediumDateString: String {
        formatted(.dateTime.month(.abbreviated).day().year())
    }
}
