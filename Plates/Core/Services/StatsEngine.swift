import Foundation

/// Pure aggregation over the collection. All date math uses `Calendar.current`;
/// all money math stays in `Decimal`.
enum StatsEngine {

    // MARK: - Year stats

    static func yearStats(year: Int, restaurants: [Restaurant]) -> YearStats {
        let calendar = Calendar.current

        var totalSpend = Decimal(0)
        var visitCount = 0
        var monthlySpend = [Decimal](repeating: 0, count: 12)
        var cuisineSpend: [Cuisine: Decimal] = [:]
        var spendByRestaurant: [UUID: (name: String, amount: Decimal)] = [:]
        var visitedRestaurantIDs = Set<UUID>()
        var newRestaurants = 0

        for restaurant in restaurants {
            if calendar.component(.year, from: restaurant.addedAt) == year {
                newRestaurants += 1
            }
            for visit in restaurant.visits {
                let components = calendar.dateComponents([.year, .month], from: visit.date)
                guard components.year == year else { continue }

                visitCount += 1
                totalSpend += visit.amountHome
                if let month = components.month, (1...12).contains(month) {
                    monthlySpend[month - 1] += visit.amountHome
                }
                cuisineSpend[restaurant.cuisine, default: 0] += visit.amountHome
                visitedRestaurantIDs.insert(restaurant.id)
                var entry = spendByRestaurant[restaurant.id] ?? (restaurant.name, 0)
                entry.amount += visit.amountHome
                spendByRestaurant[restaurant.id] = entry
            }
        }

        let cuisineRanking = cuisineSpend
            .map { CuisineAmount(cuisine: $0.key, amount: $0.value) }
            .sorted {
                $0.amount != $1.amount
                    ? $0.amount > $1.amount
                    : $0.cuisine.rawValue < $1.cuisine.rawValue
            }

        let topRestaurants = spendByRestaurant.values
            .map { NamedAmount(name: $0.name, amount: $0.amount) }
            .sorted { $0.amount != $1.amount ? $0.amount > $1.amount : $0.name < $1.name }
            .prefix(5)

        let averagePerVisit: Decimal =
            visitCount > 0 ? roundedMoney(totalSpend / Decimal(visitCount)) : 0

        return YearStats(year: year,
                         totalSpendHome: totalSpend,
                         visitCount: visitCount,
                         restaurantsVisited: visitedRestaurantIDs.count,
                         newRestaurants: newRestaurants,
                         monthlySpend: monthlySpend,
                         cuisineSpend: cuisineRanking,
                         topRestaurants: Array(topRestaurants),
                         averagePerVisit: averagePerVisit)
    }

    // MARK: - Lifetime stats

    static func lifetime(restaurants: [Restaurant]) -> LifetimeStats {
        let calendar = Calendar.current

        var visitCount = 0
        var totalSpend = Decimal(0)
        var starsCollected = 0
        var michelinPlateCount = 0
        var bibGourmandCount = 0
        var countries = Set<String>()
        var cities = Set<String>()
        var cuisineTally: [Cuisine: Int] = [:]
        var dishTally: [String: Int] = [:]

        for restaurant in restaurants {
            // Collection semantic: each distinct restaurant contributes its
            // stars exactly once, no matter how many visits it has.
            starsCollected += max(0, restaurant.michelinStars)
            if restaurant.michelinStars > 0 { michelinPlateCount += 1 }
            if restaurant.isBibGourmand { bibGourmandCount += 1 }

            let countryCode = restaurant.countryCode
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            if !countryCode.isEmpty {
                countries.insert(countryCode)
            }
            let city = restaurant.city.trimmingCharacters(in: .whitespacesAndNewlines)
            if !city.isEmpty {
                cities.insert("\(city.lowercased())|\(countryCode)")
            }

            cuisineTally[restaurant.cuisine, default: 0] += 1

            for visit in restaurant.visits {
                visitCount += 1
                totalSpend += visit.amountHome
                for item in visit.lineItems {
                    let dish = normalizedDishName(item.name)
                    guard !dish.isEmpty else { continue }
                    dishTally[dish, default: 0] += 1
                }
            }
        }

        let cuisineCounts = cuisineTally
            .map { CuisineCount(cuisine: $0.key, count: $0.value) }
            .sorted {
                $0.count != $1.count
                    ? $0.count > $1.count
                    : $0.cuisine.rawValue < $1.cuisine.rawValue
            }

        let favoriteDishes = dishTally
            .map { DishCount(name: $0.key.capitalized, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
            .prefix(10)

        let months = Set(restaurants.compactMap { monthIndex(of: $0.addedAt, calendar: calendar) })

        return LifetimeStats(plateCount: restaurants.count,
                             visitCount: visitCount,
                             totalSpendHome: totalSpend,
                             michelinStarsCollected: starsCollected,
                             michelinPlateCount: michelinPlateCount,
                             bibGourmandCount: bibGourmandCount,
                             countryCount: countries.count,
                             cityCount: cities.count,
                             cuisineCounts: cuisineCounts,
                             favoriteCuisine: cuisineCounts.first?.cuisine,
                             favoriteDishes: Array(favoriteDishes),
                             currentMonthlyStreak: currentStreak(months: months, calendar: calendar),
                             bestMonthlyStreak: bestStreak(months: months))
    }

    // MARK: - Years

    static func availableYears(restaurants: [Restaurant]) -> [Int] {
        let calendar = Calendar.current
        var years: Set<Int> = [calendar.component(.year, from: Date())]
        for restaurant in restaurants {
            for visit in restaurant.visits {
                years.insert(calendar.component(.year, from: visit.date))
            }
        }
        return years.sorted(by: >)
    }

    // MARK: - Dish normalization

    /// Lowercases, trims, strips quantity prefixes ("2x ", "2 x ", "x2 ", "2 ")
    /// and collapses runs of whitespace.
    private static func normalizedDishName(_ raw: String) -> String {
        var name = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let quantityPrefixes = [
            "^\\d+\\s*[x×]\\s*",   // "2x ", "2 x ", "2x"
            "^[x×]\\s*\\d+\\s+",   // "x2 "
            "^\\d+\\s+"            // "2 "
        ]
        for pattern in quantityPrefixes {
            if let range = name.range(of: pattern, options: .regularExpression) {
                name = String(name[range.upperBound...])
                break
            }
        }
        name = name.replacingOccurrences(of: "\\s+",
                                         with: " ",
                                         options: .regularExpression)
        return name.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Streaks

    /// A date's absolute month index (year * 12 + zero-based month).
    private static func monthIndex(of date: Date, calendar: Calendar) -> Int? {
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let year = components.year, let month = components.month else { return nil }
        return year * 12 + (month - 1)
    }

    /// Consecutive months with at least one new restaurant, counting back from
    /// the current month. If the current month is empty it isn't counted yet —
    /// the streak is measured back from last month instead (grace period).
    private static func currentStreak(months: Set<Int>, calendar: Calendar) -> Int {
        guard let now = monthIndex(of: Date(), calendar: calendar) else { return 0 }
        var cursor = months.contains(now) ? now : now - 1
        var streak = 0
        while months.contains(cursor) {
            streak += 1
            cursor -= 1
        }
        return streak
    }

    /// The longest run of consecutive months ever achieved.
    private static func bestStreak(months: Set<Int>) -> Int {
        var best = 0
        var run = 0
        var previous: Int?
        for index in months.sorted() {
            if let previous, index == previous + 1 {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = index
        }
        return best
    }

    // MARK: - Helpers

    private static func roundedMoney(_ value: Decimal) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, 2, .plain)
        return output
    }
}
