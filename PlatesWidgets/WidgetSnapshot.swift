import Foundation

/// Duplicate of the app target's `WidgetSnapshot` (Plates/Core/Models/Models.swift).
/// The widget extension cannot import app code — keep this in sync with the app.
struct WidgetSnapshot: Codable {
    var plateCount: Int
    var starCount: Int
    var countryCount: Int
    var yearSpendHome: Double
    var homeCurrencyCode: String
    var topCuisineName: String
    var topCuisineEmoji: String
    var updatedAt: Date
}

/// Reads the snapshot the app writes into the shared App Group container.
enum WidgetSnapshotLoader {
    static let appGroupID = "group.com.dxzhang.plates"
    static let fileName = "snapshot.json"

    /// Fallback used for placeholders, previews, and before the app has ever
    /// written a snapshot.
    static let sample = WidgetSnapshot(plateCount: 12,
                                       starCount: 5,
                                       countryCount: 4,
                                       yearSpendHome: 2840,
                                       homeCurrencyCode: "USD",
                                       topCuisineName: "Japanese",
                                       topCuisineEmoji: "🍣",
                                       updatedAt: Date())

    /// The latest snapshot written by the app, or nil if unavailable/corrupt.
    static func load() -> WidgetSnapshot? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return nil }
        let url = container.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601   // must match WidgetSnapshotWriter's encoder
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    /// Never-failing variant for timeline entries.
    static func loadOrSample() -> WidgetSnapshot {
        load() ?? sample
    }
}
