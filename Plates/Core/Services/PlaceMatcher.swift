import CoreLocation
import Foundation
import MapKit
import Observation

// MARK: - PlaceMatcher

enum PlaceMatcher {

    /// POI categories that can plausibly produce a dining receipt.
    private static let diningCategories: [MKPointOfInterestCategory] = [
        .restaurant, .cafe, .bakery, .brewery, .winery, .nightlife, .foodMarket
    ]

    /// MKLocalSearch (restaurant/café POIs preferred). Global search seeded by
    /// `query`; ranked by distance when `near` is provided. Fills city/country
    /// / countryCode from placemarks. Never throws — returns [] on any failure.
    static func search(query: String, near: CLLocationCoordinate2D?) async -> [PlaceMatch] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        var items: [MKMapItem] = []
        if let near {
            let localRegion = MKCoordinateRegion(center: near,
                                                 latitudinalMeters: 5_000,
                                                 longitudinalMeters: 5_000)
            items = await runSearch(query: trimmedQuery, region: localRegion)
            if items.count < 3 {
                items += await runSearch(query: trimmedQuery, region: MKCoordinateRegion(.world))
            }
        } else {
            items = await runSearch(query: trimmedQuery, region: MKCoordinateRegion(.world))
        }

        let matches = items.compactMap { placeMatch(for: $0, near: near) }
        let unique = dedup(matches)
        return Array(sortedByDistance(unique).prefix(12))
    }

    // MARK: Search execution

    private static func runSearch(query: String, region: MKCoordinateRegion) async -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: diningCategories)
        request.region = region
        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems
        } catch {
            return []
        }
    }

    // MARK: Mapping

    private static func placeMatch(for item: MKMapItem, near: CLLocationCoordinate2D?) -> PlaceMatch? {
        let placemark = item.placemark
        let coordinate = placemark.coordinate
        guard let name = item.name ?? placemark.name, !name.isEmpty else { return nil }

        let city = placemark.locality
            ?? placemark.subAdministrativeArea
            ?? placemark.administrativeArea
            ?? ""
        let country = placemark.country ?? ""
        let countryCode = placemark.isoCountryCode?.uppercased() ?? ""

        let street = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0 }
            .joined(separator: " ")
        let address = [street, city]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        var distanceMeters: Double?
        if let near {
            let origin = CLLocation(latitude: near.latitude, longitude: near.longitude)
            let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            distanceMeters = origin.distance(from: target)
        }

        return PlaceMatch(name: name,
                          latitude: coordinate.latitude,
                          longitude: coordinate.longitude,
                          city: city,
                          country: country,
                          countryCode: countryCode,
                          address: address,
                          poiCategory: item.pointOfInterestCategory?.rawValue,
                          distanceMeters: distanceMeters)
    }

    // MARK: Dedup & ordering

    /// Drops later results whose normalized name matches an earlier one within 100 m.
    private static func dedup(_ matches: [PlaceMatch]) -> [PlaceMatch] {
        var kept: [PlaceMatch] = []
        var keptKeys: [(name: String, location: CLLocation)] = []
        for match in matches {
            let key = normalized(match.name)
            let location = CLLocation(latitude: match.latitude, longitude: match.longitude)
            let isDuplicate = keptKeys.contains {
                $0.name == key && $0.location.distance(from: location) < 100
            }
            if !isDuplicate {
                kept.append(match)
                keptKeys.append((key, location))
            }
        }
        return kept
    }

    /// Distance ascending, nil distances last; stable for ties and nil-only lists.
    private static func sortedByDistance(_ matches: [PlaceMatch]) -> [PlaceMatch] {
        matches.enumerated()
            .sorted { lhs, rhs in
                switch (lhs.element.distanceMeters, rhs.element.distanceMeters) {
                case let (l?, r?): return l == r ? lhs.offset < rhs.offset : l < r
                case (.some, .none): return true
                case (.none, .some): return false
                case (.none, .none): return lhs.offset < rhs.offset
                }
            }
            .map(\.element)
    }

    private static func normalized(_ name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                  locale: Locale(identifier: "en_US_POSIX"))
        let scalars = folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        return String(String.UnicodeScalarView(scalars))
    }
}

// MARK: - LocationProvider

/// One-shot location provider for seeding place search and Michelin matching.
/// Denial is handled silently — `lastCoordinate` simply stays nil.
@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {

    static let shared = LocationProvider()

    private(set) var lastCoordinate: CLLocationCoordinate2D?

    @ObservationIgnored private var wantsLocation = false

    @ObservationIgnored private lazy var manager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.delegate = self
        return manager
    }()

    private override init() {
        super.init()
    }

    /// Requests when-in-use permission if needed and refreshes a one-shot location.
    func request() {
        wantsLocation = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if wantsLocation { manager.requestLocation() }
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        wantsLocation = false
        Task { @MainActor in
            self.lastCoordinate = coordinate
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silent by design: a failed or denied fix leaves lastCoordinate nil.
    }
}
