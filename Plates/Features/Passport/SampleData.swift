#if DEBUG
import Foundation
import SwiftData

/// Debug-only seed data: a believable world-spanning collection with Michelin
/// rarities, everyday favorites, multi-visit spots, and dates spread across
/// the last 20 months so streaks, stats, and the story all look real.
enum SampleData {

    /// Inserts 14 restaurants (with visits and line items) into `context`,
    /// saves, refreshes the widget snapshot, and syncs earned-badge state.
    static func load(into context: ModelContext) {
        var all: [Restaurant] = []

        func add(_ restaurant: Restaurant,
                 monthsAgo: Int,
                 day: Int,
                 visits: [Visit]) {
            restaurant.addedAt = date(monthsAgo: monthsAgo, day: day, hour: 13)
            context.insert(restaurant)
            for visit in visits {
                context.insert(visit)
                visit.restaurant = restaurant
            }
            all.append(restaurant)
        }

        // This month — a neighborhood café.
        add(Restaurant(name: "Sey Coffee",
                       latitude: 40.7176, longitude: -73.9368,
                       city: "Brooklyn", country: "United States", countryCode: "US",
                       cuisine: .cafe),
            monthsAgo: 0, day: 3,
            visits: [
                visit(monthsAgo: 0, day: 3, amount: "14.50", currency: "USD",
                      dishes: ["Flat White", "Cardamom Bun"]),
                visit(monthsAgo: 0, day: 8, amount: "18.00", currency: "USD",
                      dishes: ["Pour Over — Ethiopia Chelbesa", "Almond Croissant"])
            ])

        // 1 month ago — a three-star pilgrimage.
        add(Restaurant(name: "Le Bernardin",
                       latitude: 40.7616, longitude: -73.9818,
                       city: "New York", country: "United States", countryCode: "US",
                       cuisine: .french, michelinStars: 3),
            monthsAgo: 1, day: 14,
            visits: [
                visit(monthsAgo: 1, day: 14, amount: "542.00", currency: "USD",
                      dishes: ["Chef's Tasting Menu", "Wine Pairing",
                               "Langoustine", "Poached Halibut"])
            ])

        // 2 months ago — a taqueria worth three trips.
        add(Restaurant(name: "Taquería Orinoco",
                       latitude: 19.4204, longitude: -99.1622,
                       city: "Mexico City", country: "Mexico", countryCode: "MX",
                       cuisine: .mexican),
            monthsAgo: 2, day: 9,
            visits: [
                visit(monthsAgo: 2, day: 9, amount: "385.00", currency: "MXN",
                      dishes: ["Tacos al Pastor", "Gringa de Chicharrón",
                               "Agua de Horchata"]),
                visit(monthsAgo: 1, day: 16, amount: "310.00", currency: "MXN",
                      dishes: ["Tacos al Pastor", "Quesadilla de Res",
                               "Refresco de Toronja"]),
                visit(monthsAgo: 0, day: 6, amount: "295.00", currency: "MXN",
                      dishes: ["Tacos de Res Norteños", "Papas Orinoco"])
            ])

        // 3 months ago — London curry house.
        add(Restaurant(name: "Dishoom Covent Garden",
                       latitude: 51.5122, longitude: -0.1266,
                       city: "London", country: "United Kingdom", countryCode: "GB",
                       cuisine: .indian),
            monthsAgo: 3, day: 18,
            visits: [
                visit(monthsAgo: 3, day: 18, amount: "64.50", currency: "GBP",
                      dishes: ["House Black Daal", "Chicken Ruby",
                               "Garlic Naan", "Mango Lassi"]),
                visit(monthsAgo: 2, day: 2, amount: "41.20", currency: "GBP",
                      dishes: ["Bacon Naan Roll", "Kejriwal", "Masala Chai"])
            ])

        // 4 months ago — Barcelona tapas bar.
        add(Restaurant(name: "El Xampanyet",
                       latitude: 41.3849, longitude: 2.1817,
                       city: "Barcelona", country: "Spain", countryCode: "ES",
                       cuisine: .spanish),
            monthsAgo: 4, day: 6,
            visits: [
                visit(monthsAgo: 4, day: 6, amount: "58.00", currency: "EUR",
                      dishes: ["Jamón Ibérico", "Boquerones",
                               "Pan con Tomate", "Cava de la Casa"])
            ])

        // 5 months ago — Austin barbecue.
        add(Restaurant(name: "Franklin Barbecue",
                       latitude: 30.2701, longitude: -97.7313,
                       city: "Austin", country: "United States", countryCode: "US",
                       cuisine: .bbq),
            monthsAgo: 5, day: 2,
            visits: [
                visit(monthsAgo: 5, day: 2, amount: "76.40", currency: "USD",
                      dishes: ["Brisket Plate", "Pork Ribs",
                               "Tipsy Texan", "Bourbon Banana Pie"])
            ])

        // 6 months ago — two stars in Tokyo.
        add(Restaurant(name: "Den",
                       latitude: 35.6690, longitude: 139.7126,
                       city: "Tokyo", country: "Japan", countryCode: "JP",
                       cuisine: .japanese, michelinStars: 2),
            monthsAgo: 6, day: 11,
            visits: [
                visit(monthsAgo: 6, day: 11, amount: "33000", currency: "JPY",
                      dishes: ["Omakase Course", "Dentucky Fried Chicken",
                               "Garden Salad", "Monaka"])
            ])

        // 8 months ago — Bib Gourmand noodles in Bangkok.
        add(Restaurant(name: "Rung Rueang Pork Noodles",
                       latitude: 13.7296, longitude: 100.5697,
                       city: "Bangkok", country: "Thailand", countryCode: "TH",
                       cuisine: .thai, isBibGourmand: true),
            monthsAgo: 8, day: 5,
            visits: [
                visit(monthsAgo: 8, day: 5, amount: "180.00", currency: "THB",
                      dishes: ["Moo Tom Yum Noodles", "Pork Wonton Soup",
                               "Thai Iced Tea"]),
                visit(monthsAgo: 8, day: 20, amount: "150.00", currency: "THB",
                      dishes: ["Dry Pork Noodles", "Fish Ball Soup"]),
                visit(monthsAgo: 5, day: 12, amount: "210.00", currency: "THB",
                      dishes: ["Moo Tom Yum Noodles", "Crispy Pork Belly",
                               "Longan Juice"])
            ])

        // 10 months ago — Modena, three stars.
        add(Restaurant(name: "Osteria Francescana",
                       latitude: 44.6448, longitude: 10.9212,
                       city: "Modena", country: "Italy", countryCode: "IT",
                       cuisine: .italian, michelinStars: 3),
            monthsAgo: 10, day: 17,
            visits: [
                visit(monthsAgo: 10, day: 17, amount: "520.00", currency: "EUR",
                      dishes: ["Five Ages of Parmigiano Reggiano",
                               "The Crunchy Part of the Lasagna",
                               "Oops! I Dropped the Lemon Tart",
                               "Wine Pairing"])
            ])

        // 12 months ago — Seoul KBBQ.
        add(Restaurant(name: "Maple Tree House",
                       latitude: 37.5339, longitude: 126.9948,
                       city: "Seoul", country: "South Korea", countryCode: "KR",
                       cuisine: .korean),
            monthsAgo: 12, day: 8,
            visits: [
                visit(monthsAgo: 12, day: 8, amount: "98000", currency: "KRW",
                      dishes: ["Prime Galbi", "Pork Belly",
                               "Kimchi Jjigae", "Mul Naengmyeon"]),
                visit(monthsAgo: 7, day: 19, amount: "84000", currency: "KRW",
                      dishes: ["Bulgogi", "Seafood Pancake", "Soju"])
            ])

        // 14 months ago — Vancouver sushi bar.
        add(Restaurant(name: "Tojo's",
                       latitude: 49.2637, longitude: -123.1252,
                       city: "Vancouver", country: "Canada", countryCode: "CA",
                       cuisine: .japanese),
            monthsAgo: 14, day: 13,
            visits: [
                visit(monthsAgo: 14, day: 13, amount: "212.00", currency: "CAD",
                      dishes: ["Omakase", "Great Tojo Roll",
                               "Sablefish Misoyaki", "Sake Flight"])
            ])

        // 16 months ago — one star in Paris.
        add(Restaurant(name: "Septime",
                       latitude: 48.8532, longitude: 2.3811,
                       city: "Paris", country: "France", countryCode: "FR",
                       cuisine: .french, michelinStars: 1),
            monthsAgo: 16, day: 22,
            visits: [
                visit(monthsAgo: 16, day: 22, amount: "190.00", currency: "EUR",
                      dishes: ["Carte Blanche Menu", "Beetroot & Smoked Eel",
                               "Natural Wine Pairing"])
            ])

        // 18 months ago — three stars in San Francisco.
        add(Restaurant(name: "Benu",
                       latitude: 37.7852, longitude: -122.3989,
                       city: "San Francisco", country: "United States", countryCode: "US",
                       cuisine: .fusion, michelinStars: 3),
            monthsAgo: 18, day: 9,
            visits: [
                visit(monthsAgo: 18, day: 9, amount: "495.00", currency: "USD",
                      dishes: ["Tasting Menu", "Thousand-Year-Old Quail Egg",
                               "Faux Shark Fin Soup", "Sesame Mochi"])
            ])

        // 20 months ago (the far edge) — a Brooklyn pizzeria, revisited often.
        add(Restaurant(name: "Roberta's",
                       latitude: 40.7051, longitude: -73.9336,
                       city: "Brooklyn", country: "United States", countryCode: "US",
                       cuisine: .pizza),
            monthsAgo: 19, day: 4,
            visits: [
                visit(monthsAgo: 19, day: 4, amount: "54.00", currency: "USD",
                      dishes: ["Bee Sting Pizza", "Caesar Salad", "Garlic Knots"]),
                visit(monthsAgo: 9, day: 15, amount: "61.00", currency: "USD",
                      dishes: ["Bee Sting Pizza", "Meatballs", "Negroni"]),
                visit(monthsAgo: 3, day: 27, amount: "48.50", currency: "USD",
                      dishes: ["Famous Original Pizza", "Spicy Soppressata",
                               "House Lager"])
            ])

        try? context.save()
        WidgetSnapshotWriter.write(restaurants: all)
        _ = BadgeEngine.newlyEarned(restaurants: all)
    }

    // MARK: - Builders

    private static func visit(monthsAgo: Int,
                              day: Int,
                              amount: String,
                              currency: String,
                              dishes: [String]) -> Visit {
        let value = Decimal(string: amount,
                            locale: Locale(identifier: "en_US_POSIX")) ?? 0
        return Visit(date: date(monthsAgo: monthsAgo, day: day),
                     amount: value,
                     currencyCode: currency,
                     amountHome: CurrencyConverter.toHome(value, from: currency),
                     lineItems: dishes.map { ParsedLineItem(name: $0, price: nil) })
    }

    /// A dinner-hour date `monthsAgo` months back on (roughly) `day`,
    /// clamped so nothing lands in the future.
    private static func date(monthsAgo: Int, day: Int, hour: Int = 19) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let base = calendar.date(byAdding: .month, value: -monthsAgo, to: now) ?? now
        var components = calendar.dateComponents([.year, .month], from: base)
        var clampedDay = min(max(day, 1), 28)
        if monthsAgo == 0 {
            clampedDay = min(clampedDay, calendar.component(.day, from: now))
        }
        components.day = clampedDay
        components.hour = hour
        components.minute = [5, 20, 35, 50][day % 4]
        return calendar.date(from: components) ?? base
    }
}
#endif
