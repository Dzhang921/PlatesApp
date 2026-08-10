import Foundation
import SwiftData
import CoreLocation

// MARK: - SwiftData models

@Model
final class Restaurant {
    var id: UUID = UUID()
    var name: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var city: String = ""
    var country: String = ""
    /// ISO 3166 alpha-2, uppercase ("US", "JP"). Empty if unknown.
    var countryCode: String = ""
    var cuisineRaw: String = Cuisine.other.rawValue
    /// 0 = not Michelin-starred, 1–3 = stars.
    var michelinStars: Int = 0
    var isBibGourmand: Bool = false
    var addedAt: Date = Date()
    var notes: String = ""
    @Relationship(deleteRule: .cascade, inverse: \Visit.restaurant)
    var visits: [Visit] = []

    init(name: String,
         latitude: Double,
         longitude: Double,
         city: String,
         country: String,
         countryCode: String,
         cuisine: Cuisine,
         michelinStars: Int = 0,
         isBibGourmand: Bool = false) {
        self.id = UUID()
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.city = city
        self.country = country
        self.countryCode = countryCode.uppercased()
        self.cuisineRaw = cuisine.rawValue
        self.michelinStars = michelinStars
        self.isBibGourmand = isBibGourmand
        self.addedAt = Date()
    }

    var cuisine: Cuisine {
        get { Cuisine(rawValue: cuisineRaw) ?? .other }
        set { cuisineRaw = newValue.rawValue }
    }
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    var isMichelin: Bool { michelinStars > 0 }
    var visitCount: Int { visits.count }
    var sortedVisits: [Visit] { visits.sorted { $0.date > $1.date } }
    var lastVisitDate: Date? { visits.map(\.date).max() }
    var totalSpendHome: Decimal { visits.reduce(Decimal(0)) { $0 + $1.amountHome } }
}

@Model
final class Visit {
    var id: UUID = UUID()
    var date: Date = Date()
    /// Amount in the receipt's original currency.
    var amount: Decimal = 0
    var currencyCode: String = "USD"
    /// Amount converted to the user's home currency at save time.
    var amountHome: Decimal = 0
    /// ImageStore file name for the receipt photo.
    var receiptImagePath: String?
    /// ImageStore file names for attached food photos.
    var foodPhotoPaths: [String] = []
    /// JSON-encoded [ParsedLineItem].
    var lineItemsData: Data?
    var restaurant: Restaurant?

    init(date: Date,
         amount: Decimal,
         currencyCode: String,
         amountHome: Decimal,
         receiptImagePath: String? = nil,
         lineItems: [ParsedLineItem] = []) {
        self.id = UUID()
        self.date = date
        self.amount = amount
        self.currencyCode = currencyCode
        self.amountHome = amountHome
        self.receiptImagePath = receiptImagePath
        self.lineItemsData = lineItems.isEmpty ? nil : try? JSONEncoder().encode(lineItems)
    }

    var lineItems: [ParsedLineItem] {
        get {
            guard let lineItemsData else { return [] }
            return (try? JSONDecoder().decode([ParsedLineItem].self, from: lineItemsData)) ?? []
        }
        set { lineItemsData = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue) }
    }
}

// MARK: - Cuisine

enum Cuisine: String, CaseIterable, Codable, Identifiable {
    case american, bbq, bakery, bar, breakfast, burgers, cafe, chinese, dessert,
         french, german, greek, indian, italian, japanese, korean, mediterranean,
         mexican, middleEastern, pizza, ramen, seafood, spanish, steakhouse, thai,
         vegetarian, vietnamese, fusion, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bbq: return "BBQ"
        case .middleEastern: return "Middle Eastern"
        case .cafe: return "Café"
        default: return rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }

    var emoji: String {
        switch self {
        case .american: return "🍔"
        case .bbq: return "🍖"
        case .bakery: return "🥐"
        case .bar: return "🍸"
        case .breakfast: return "🍳"
        case .burgers: return "🍟"
        case .cafe: return "☕️"
        case .chinese: return "🥟"
        case .dessert: return "🍰"
        case .french: return "🥖"
        case .german: return "🥨"
        case .greek: return "🥙"
        case .indian: return "🍛"
        case .italian: return "🍝"
        case .japanese: return "🍣"
        case .korean: return "🍚"
        case .mediterranean: return "🫒"
        case .mexican: return "🌮"
        case .middleEastern: return "🧆"
        case .pizza: return "🍕"
        case .ramen: return "🍜"
        case .seafood: return "🦞"
        case .spanish: return "🥘"
        case .steakhouse: return "🥩"
        case .thai: return "🌶️"
        case .vegetarian: return "🥗"
        case .vietnamese: return "🍲"
        case .fusion: return "✨"
        case .other: return "🍽️"
        }
    }
}

// MARK: - Receipt parsing types

struct ParsedLineItem: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var price: Decimal?
}

struct ParsedReceipt {
    var merchantName: String?
    var date: Date?
    var total: Decimal?
    var currencyCode: String?
    var lineItems: [ParsedLineItem] = []
    var rawLines: [String] = []
}

// MARK: - Place matching types

struct PlaceMatch: Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var latitude: Double
    var longitude: Double
    var city: String
    var country: String
    /// ISO alpha-2, uppercase. Empty if unknown.
    var countryCode: String
    var address: String
    /// Raw MKPointOfInterestCategory rawValue, if any (e.g. "MKPOICategoryRestaurant").
    var poiCategory: String?
    var distanceMeters: Double?
}

// MARK: - Michelin catalog types

struct MichelinRecord: Codable, Hashable {
    var name: String
    var latitude: Double
    var longitude: Double
    var city: String
    var country: String
    /// 1–3 stars; 0 means Bib Gourmand.
    var stars: Int
    var cuisine: String?
}

// MARK: - Stats types

struct CuisineAmount: Identifiable {
    var cuisine: Cuisine
    var amount: Decimal
    var id: String { cuisine.rawValue }
}

struct CuisineCount: Identifiable {
    var cuisine: Cuisine
    var count: Int
    var id: String { cuisine.rawValue }
}

struct NamedAmount: Identifiable {
    var name: String
    var amount: Decimal
    var id: String { name }
}

struct DishCount: Identifiable {
    var name: String
    var count: Int
    var id: String { name }
}

struct YearStats {
    var year: Int
    var totalSpendHome: Decimal
    var visitCount: Int
    var restaurantsVisited: Int
    var newRestaurants: Int
    /// 12 entries, January first.
    var monthlySpend: [Decimal]
    /// Sorted by amount, descending.
    var cuisineSpend: [CuisineAmount]
    /// Top 5 by spend, descending.
    var topRestaurants: [NamedAmount]
    var averagePerVisit: Decimal
}

struct LifetimeStats {
    var plateCount: Int
    var visitCount: Int
    var totalSpendHome: Decimal
    /// Sum of stars across distinct Michelin restaurants visited.
    var michelinStarsCollected: Int
    var michelinPlateCount: Int
    var bibGourmandCount: Int
    var countryCount: Int
    var cityCount: Int
    /// Sorted by count, descending.
    var cuisineCounts: [CuisineCount]
    var favoriteCuisine: Cuisine?
    /// From visit line items, sorted by count descending, top 10.
    var favoriteDishes: [DishCount]
    var currentMonthlyStreak: Int
    var bestMonthlyStreak: Int
}

// MARK: - Badges

enum BadgeTier: Int, Comparable {
    case bronze = 0, silver, gold, michelin
    static func < (lhs: BadgeTier, rhs: BadgeTier) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct Badge: Identifiable {
    /// Stable string key, e.g. "first-plate".
    var id: String
    var name: String
    var blurb: String
    /// SF Symbol name.
    var symbol: String
    var tier: BadgeTier
    var earned: Bool
    /// 0...1 toward earning.
    var progress: Double
}

// MARK: - Widget snapshot (duplicated in PlatesWidgets/WidgetSnapshot.swift — keep in sync)

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

// MARK: - Small shared helpers

extension Decimal {
    var plDouble: Double { (self as NSDecimalNumber).doubleValue }
}
