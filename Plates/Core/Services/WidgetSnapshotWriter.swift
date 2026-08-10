import Foundation
import WidgetKit

/// Publishes a small JSON snapshot of the collection into the App Group so the
/// widget extension (which cannot import app code) can render without the app.
///
/// The widget decodes `snapshot.json` with `JSONDecoder` using the `.iso8601`
/// date strategy — the encoder here MUST stay in lockstep.
enum WidgetSnapshotWriter {

    static let appGroupID = "group.com.dxzhang.plates"

    private static let fileName = "snapshot.json"

    /// Builds the current `WidgetSnapshot` from the collection, writes it to
    /// `<appGroup>/snapshot.json`, and asks WidgetKit to reload all timelines.
    /// Safely no-ops if the App Group container is unavailable.
    static func write(restaurants: [Restaurant]) {
        let lifetime = StatsEngine.lifetime(restaurants: restaurants)
        let currentYear = Calendar.current.component(.year, from: Date())
        let yearStats = StatsEngine.yearStats(year: currentYear, restaurants: restaurants)

        let topCuisine = lifetime.cuisineCounts.first?.cuisine
        let snapshot = WidgetSnapshot(
            plateCount: lifetime.plateCount,
            starCount: lifetime.michelinStarsCollected,
            countryCount: lifetime.countryCount,
            yearSpendHome: yearStats.totalSpendHome.plDouble,
            homeCurrencyCode: CurrencyConverter.homeCurrency,
            topCuisineName: topCuisine?.displayName ?? "Nothing yet",
            topCuisineEmoji: topCuisine?.emoji ?? "🍽️",
            updatedAt: Date())

        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: container.appendingPathComponent(fileName), options: .atomic)
        } catch {
            return
        }

        WidgetCenter.shared.reloadAllTimelines()
    }
}
