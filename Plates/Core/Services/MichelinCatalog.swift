import Foundation
import CoreLocation

/// Offline Michelin Guide catalog. Loads `Resources/michelin.json` once, lazily,
/// and answers fuzzy name lookups so Capture can auto-badge starred restaurants.
enum MichelinCatalog {

    // MARK: - Public API

    /// Every record in the bundled dataset. Loaded once on first access.
    static var all: [MichelinRecord] { storage.records }

    /// Fuzzy name match against the catalog.
    ///
    /// Both sides are normalized (lowercased, diacritics stripped, punctuation
    /// removed, whitespace collapsed, generic filler tokens dropped) and then
    /// compared: exact normalized equality wins outright; otherwise one name's
    /// token set containing the other's, or a token Jaccard similarity >= 0.6,
    /// counts as a hit. When `near` is provided candidates must lie within
    /// ~60 km; without a coordinate only the stronger equality/containment
    /// matches are accepted.
    static func match(name: String, near: CLLocationCoordinate2D?) -> MichelinRecord? {
        let query = normalize(name)
        guard !query.text.isEmpty, !query.tokens.isEmpty else { return nil }

        let origin = near.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        var best: (record: MichelinRecord, score: Double, distance: Double)?

        for entry in storage.entries {
            var distance = Double.greatestFiniteMagnitude
            if let origin {
                distance = origin.distance(from: entry.location)
                guard distance <= maxMatchDistanceMeters else { continue }
            }

            guard let score = score(query: query, candidate: entry.normalized,
                                    requireStrong: origin == nil) else { continue }

            if let current = best {
                if score > current.score || (score == current.score && distance < current.distance) {
                    best = (entry.record, score, distance)
                }
            } else {
                best = (entry.record, score, distance)
            }
        }
        return best?.record
    }

    // MARK: - Matching internals

    private static let maxMatchDistanceMeters: CLLocationDistance = 60_000
    private static let jaccardThreshold = 0.6
    private static let genericTokens: Set<String> = [
        "restaurant", "restaurante", "ristorante", "the"
    ]

    private struct NormalizedName {
        var text: String
        var tokens: Set<String>
    }

    private struct Entry {
        var record: MichelinRecord
        var normalized: NormalizedName
        var location: CLLocation
    }

    private struct Storage {
        var records: [MichelinRecord]
        var entries: [Entry]
    }

    private struct CatalogFile: Decodable {
        var asOf: String
        var records: [MichelinRecord]
    }

    /// `static let` initialization is lazy and thread-safe; the JSON is decoded
    /// exactly once, on first use.
    private static let storage: Storage = {
        guard let url = Bundle.main.url(forResource: "michelin", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(CatalogFile.self, from: data) else {
            return Storage(records: [], entries: [])
        }
        let entries = file.records.map { record in
            Entry(record: record,
                  normalized: normalize(record.name),
                  location: CLLocation(latitude: record.latitude, longitude: record.longitude))
        }
        return Storage(records: file.records, entries: entries)
    }()

    /// Lowercase, strip diacritics, drop punctuation, collapse whitespace,
    /// and remove generic filler tokens.
    private static func normalize(_ raw: String) -> NormalizedName {
        let folded = raw
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                     locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        let cleanedScalars = folded.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) { return Character(scalar) }
            return " "
        }
        let tokens = String(cleanedScalars)
            .split(separator: " ")
            .map(String.init)
            .filter { !genericTokens.contains($0) }
        return NormalizedName(text: tokens.joined(separator: " "), tokens: Set(tokens))
    }

    /// Higher is better; nil means no acceptable match.
    /// Exact equality scores 3, token containment 2 + Jaccard, Jaccard-only
    /// 1 + Jaccard. With `requireStrong` (no location gate available) the
    /// Jaccard-only tier is rejected.
    private static func score(query: NormalizedName,
                              candidate: NormalizedName,
                              requireStrong: Bool) -> Double? {
        guard !candidate.tokens.isEmpty else { return nil }
        if query.text == candidate.text { return 3.0 }

        let intersection = query.tokens.intersection(candidate.tokens)
        guard !intersection.isEmpty else { return nil }
        let union = query.tokens.union(candidate.tokens)
        let jaccard = Double(intersection.count) / Double(union.count)

        let contained = intersection.count == query.tokens.count
            || intersection.count == candidate.tokens.count
        if contained { return 2.0 + jaccard }
        if requireStrong { return nil }
        return jaccard >= jaccardThreshold ? 1.0 + jaccard : nil
    }
}
