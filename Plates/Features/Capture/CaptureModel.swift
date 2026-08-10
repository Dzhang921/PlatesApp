import CoreLocation
import Foundation
import SwiftData
import SwiftUI
import VisionKit

/// State machine driving the capture flow: scan → parse → confirm → celebrate.
@MainActor
@Observable
final class CaptureModel {

    enum Step: Equatable {
        case scanner
        case manual
        case parsing
        case confirm
        case celebration
    }

    // MARK: - Flow state

    var step: Step

    /// Scanned or picked receipt pages. The first page becomes the saved receipt image.
    var receiptImages: [UIImage] = []

    // MARK: - Editable receipt fields

    var merchantName: String = ""
    var visitDate: Date = .now
    var totalText: String = ""
    var currencyCode: String = CurrencyConverter.homeCurrency
    var lineItems: [ParsedLineItem] = []

    // MARK: - Place matching

    var placeQuery: String = ""
    var candidates: [PlaceMatch] = []
    var isSearchingPlaces = false
    var selectedPlace: PlaceMatch?

    /// Existing collection, kept fresh by the confirm screen's @Query.
    @ObservationIgnored var existingRestaurants: [Restaurant] = []

    // MARK: - Enrichment

    var michelin: MichelinRecord?
    var cuisine: Cuisine = .other
    var userPickedCuisine = false

    // MARK: - Duplicate detection

    var duplicateOf: Restaurant?
    var visitNumber: Int { (duplicateOf?.visitCount ?? 0) + 1 }

    // MARK: - Save & celebration

    var showPaywall = false
    var savedRestaurant: Restaurant?
    var savedIsNew = true
    var earnedBadges: [Badge] = []

    init() {
        step = VNDocumentCameraViewController.isSupported ? .scanner : .manual
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "captureManual") { step = .manual }
        #endif
    }

    // MARK: - Derived

    var totalAmount: Decimal? {
        let cleaned = totalText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return Decimal(string: cleaned)
    }

    /// Saving requires a picked place so the plate can light up on the globe.
    var canSave: Bool { selectedPlace != nil }

    // MARK: - Scan → parse

    func handleScan(_ images: [UIImage]) {
        guard !images.isEmpty else {
            switchToManual()
            return
        }
        receiptImages = images
        LocationProvider.shared.request()
        withAnimation(.easeInOut(duration: 0.25)) { step = .parsing }
        Task {
            let parsed = await ReceiptParser.parse(images: images)
            apply(parsed)
            arriveAtConfirm()
        }
    }

    func switchToManual() {
        withAnimation(.easeInOut(duration: 0.25)) { step = .manual }
    }

    /// Manual form's "Continue" — fields are already bound to this model.
    func finishManualEntry() {
        merchantName = merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        arriveAtConfirm()
    }

    private func apply(_ parsed: ParsedReceipt) {
        if let merchant = parsed.merchantName, !merchant.isEmpty {
            merchantName = merchant
        }
        if let date = parsed.date {
            visitDate = date
        }
        if let total = parsed.total {
            totalText = NSDecimalNumber(decimal: total).stringValue
        }
        if let code = parsed.currencyCode,
           CurrencyConverter.supportedCurrencies.contains(code.uppercased()) {
            currencyCode = code.uppercased()
        }
        lineItems = parsed.lineItems
    }

    private func arriveAtConfirm() {
        placeQuery = merchantName
        withAnimation(.easeInOut(duration: 0.25)) { step = .confirm }
        Task { await searchPlaces() }
        Task { await classifyCuisine() }
    }

    // MARK: - Place search & selection

    func searchPlaces() async {
        let query = placeQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            candidates = []
            return
        }
        isSearchingPlaces = true
        let results = await PlaceMatcher.search(query: query,
                                                near: LocationProvider.shared.lastCoordinate)
        candidates = results
        isSearchingPlaces = false
        // Auto-select only when the top hit clearly is the merchant on the receipt.
        if selectedPlace == nil,
           let first = results.first,
           Self.fuzzyEqual(Self.normalized(first.name), Self.normalized(merchantName)) {
            select(first)
        }
    }

    func select(_ place: PlaceMatch) {
        Haptics.tap()
        selectedPlace = place
        let coordinate = CLLocationCoordinate2D(latitude: place.latitude,
                                                longitude: place.longitude)
        michelin = MichelinCatalog.match(name: place.name, near: coordinate)
        duplicateOf = existingDuplicate(for: place)
        if !userPickedCuisine {
            Task { await classifyCuisine() }
        }
    }

    func pickCuisine(_ cuisine: Cuisine) {
        Haptics.tap()
        userPickedCuisine = true
        self.cuisine = cuisine
    }

    func removeLineItems(at offsets: IndexSet) {
        lineItems.remove(atOffsets: offsets)
    }

    private func classifyCuisine() async {
        let name = selectedPlace?.name ?? merchantName
        guard !name.isEmpty else { return }
        let classified = await CuisineClassifier.classify(restaurantName: name,
                                                          dishNames: lineItems.map(\.name),
                                                          poiHint: selectedPlace?.poiCategory)
        if !userPickedCuisine {
            cuisine = classified
        }
    }

    // MARK: - Duplicate detection

    private func existingDuplicate(for place: PlaceMatch) -> Restaurant? {
        let placeName = Self.normalized(place.name)
        let placeLocation = CLLocation(latitude: place.latitude, longitude: place.longitude)
        return existingRestaurants.first { restaurant in
            let distance = placeLocation.distance(from: CLLocation(latitude: restaurant.latitude,
                                                                   longitude: restaurant.longitude))
            guard distance < 150 else { return false }
            return Self.fuzzyEqual(placeName, Self.normalized(restaurant.name))
        }
    }

    private static let fillerWords: Set<String> = [
        "the", "le", "la", "el", "los", "las", "il", "di", "de", "da",
        "restaurant", "ristorante", "cafe", "bar", "bistro", "kitchen", "and"
    ]

    static func normalized(_ name: String) -> String {
        name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !fillerWords.contains($0) }
            .joined(separator: " ")
    }

    static func fuzzyEqual(_ a: String, _ b: String) -> Bool {
        guard !a.isEmpty, !b.isEmpty else { return false }
        return a == b || a.contains(b) || b.contains(a)
    }

    // MARK: - Save

    /// Gates NEW restaurants behind the free limit; repeat visits are never gated.
    func attemptSave(context: ModelContext, store: StoreService, restaurants: [Restaurant]) {
        existingRestaurants = restaurants
        guard let place = selectedPlace else { return }
        if duplicateOf == nil, !store.canAddRestaurant(currentCount: restaurants.count) {
            showPaywall = true
            return
        }
        save(place: place, context: context)
    }

    private func save(place: PlaceMatch, context: ModelContext) {
        let receiptPath = receiptImages.first.flatMap { ImageStore.save($0) }
        let amount = totalAmount ?? 0
        let visit = Visit(date: visitDate,
                          amount: amount,
                          currencyCode: currencyCode,
                          amountHome: CurrencyConverter.toHome(amount, from: currencyCode),
                          receiptImagePath: receiptPath,
                          lineItems: lineItems)

        if let existing = duplicateOf {
            existing.visits.append(visit)
            savedRestaurant = existing
            savedIsNew = false
        } else {
            let stars = michelin.map { max($0.stars, 0) } ?? 0
            let restaurant = Restaurant(name: place.name,
                                        latitude: place.latitude,
                                        longitude: place.longitude,
                                        city: place.city,
                                        country: place.country,
                                        countryCode: place.countryCode,
                                        cuisine: cuisine,
                                        michelinStars: stars,
                                        isBibGourmand: michelin != nil && stars == 0)
            context.insert(restaurant)
            restaurant.visits.append(visit)
            savedRestaurant = restaurant
            savedIsNew = true
            UserDefaults.standard.set(restaurant.id.uuidString, forKey: "pendingSpotlightID")
        }

        try? context.save()

        let fresh = (try? context.fetch(FetchDescriptor<Restaurant>())) ?? []
        earnedBadges = BadgeEngine.newlyEarned(restaurants: fresh)
        WidgetSnapshotWriter.write(restaurants: fresh)

        Haptics.celebrate()
        withAnimation(.easeInOut(duration: 0.3)) { step = .celebration }
    }
}
