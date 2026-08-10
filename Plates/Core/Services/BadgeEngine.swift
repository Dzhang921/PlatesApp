import Foundation

/// The fixed badge catalog and earned-badge bookkeeping.
///
/// Badges are computed against `StatsEngine.lifetime(restaurants:)` and always
/// returned in a stable display order. `newlyEarned(restaurants:)` diffs the
/// currently earned set against the IDs persisted in `UserDefaults` (key
/// `"earnedBadgeIDs"`) so the capture flow can celebrate only fresh unlocks.
enum BadgeEngine {

    private static let earnedIDsKey = "earnedBadgeIDs"

    // MARK: - Catalog

    private struct Spec {
        let id: String
        let name: String
        let blurb: String
        let symbol: String
        let tier: BadgeTier
        let target: Int
        let metric: (LifetimeStats) -> Int
    }

    /// The full catalog, in display order.
    private static let catalog: [Spec] = [
        // Collection size
        Spec(id: "first-plate", name: "First Plate",
             blurb: "Your collection begins with a single plate.",
             symbol: "fork.knife", tier: .bronze, target: 1,
             metric: { $0.plateCount }),
        Spec(id: "plates-10", name: "Ten Plates",
             blurb: "Ten restaurants collected and lit on the globe.",
             symbol: "square.grid.2x2.fill", tier: .bronze, target: 10,
             metric: { $0.plateCount }),
        Spec(id: "plates-25", name: "Twenty-Five",
             blurb: "A quarter century of plates in the cabinet.",
             symbol: "square.grid.3x3.fill", tier: .silver, target: 25,
             metric: { $0.plateCount }),
        Spec(id: "plates-50", name: "Half Century",
             blurb: "Fifty restaurants — a serious collection.",
             symbol: "trophy.fill", tier: .gold, target: 50,
             metric: { $0.plateCount }),
        Spec(id: "plates-100", name: "The Hundred",
             blurb: "One hundred plates. A true collector.",
             symbol: "laurel.leading", tier: .gold, target: 100,
             metric: { $0.plateCount }),

        // Michelin
        Spec(id: "first-michelin", name: "First Star",
             blurb: "Your first Michelin star, collected forever.",
             symbol: "star.fill", tier: .michelin, target: 1,
             metric: { $0.michelinStarsCollected }),
        Spec(id: "stars-3", name: "Three Stars",
             blurb: "Three Michelin stars to your name.",
             symbol: "star.circle.fill", tier: .michelin, target: 3,
             metric: { $0.michelinStarsCollected }),
        Spec(id: "stars-10", name: "Constellation",
             blurb: "Ten stars — fine dining forms a pattern.",
             symbol: "sparkles", tier: .michelin, target: 10,
             metric: { $0.michelinStarsCollected }),
        Spec(id: "stars-25", name: "Galaxy",
             blurb: "Twenty-five stars light up your night sky.",
             symbol: "moon.stars.fill", tier: .michelin, target: 25,
             metric: { $0.michelinStarsCollected }),
        Spec(id: "bib-first", name: "Bib Gourmand",
             blurb: "Great food at an honest price — collected.",
             symbol: "face.smiling", tier: .bronze, target: 1,
             metric: { $0.bibGourmandCount }),

        // Cuisines
        Spec(id: "cuisines-5", name: "Taste Explorer",
             blurb: "Five different cuisines on your table.",
             symbol: "fork.knife.circle.fill", tier: .bronze, target: 5,
             metric: { $0.cuisineCounts.count }),
        Spec(id: "cuisines-10", name: "World Palate",
             blurb: "Ten cuisines and still hungry for more.",
             symbol: "globe.americas.fill", tier: .silver, target: 10,
             metric: { $0.cuisineCounts.count }),
        Spec(id: "cuisines-15", name: "Omnivore",
             blurb: "Fifteen cuisines — you'll try anything once.",
             symbol: "globe.europe.africa.fill", tier: .gold, target: 15,
             metric: { $0.cuisineCounts.count }),

        // Countries
        Spec(id: "countries-3", name: "Border Crosser",
             blurb: "Eat your way through three countries.",
             symbol: "airplane", tier: .bronze, target: 3,
             metric: { $0.countryCount }),
        Spec(id: "countries-5", name: "Jet Setter",
             blurb: "Five countries stamped into your passport.",
             symbol: "airplane.departure", tier: .silver, target: 5,
             metric: { $0.countryCount }),
        Spec(id: "countries-10", name: "Globetrotter",
             blurb: "Ten countries. The world is your table.",
             symbol: "globe", tier: .gold, target: 10,
             metric: { $0.countryCount }),

        // Streaks (best monthly streak)
        Spec(id: "streak-3", name: "On a Roll",
             blurb: "A new plate three months in a row.",
             symbol: "flame", tier: .bronze, target: 3,
             metric: { $0.bestMonthlyStreak }),
        Spec(id: "streak-6", name: "Regular",
             blurb: "Six straight months of discovery.",
             symbol: "flame.fill", tier: .silver, target: 6,
             metric: { $0.bestMonthlyStreak }),
        Spec(id: "streak-12", name: "A Full Year",
             blurb: "A new restaurant every month for a year.",
             symbol: "calendar", tier: .gold, target: 12,
             metric: { $0.bestMonthlyStreak }),
    ]

    // MARK: - API

    /// The full badge catalog, in display order, with progress computed
    /// against the current collection.
    static func badges(restaurants: [Restaurant]) -> [Badge] {
        let stats = StatsEngine.lifetime(restaurants: restaurants)
        return catalog.map { spec in
            let current = spec.metric(stats)
            let progress = min(1, Double(current) / Double(max(spec.target, 1)))
            return Badge(id: spec.id,
                         name: spec.name,
                         blurb: spec.blurb,
                         symbol: spec.symbol,
                         tier: spec.tier,
                         earned: progress >= 1,
                         progress: progress)
        }
    }

    /// Diffs the currently earned badges against the persisted earned-ID set,
    /// persists the union, and returns only the badges earned since the last
    /// call (in display order). Empty on first call if nothing is earned yet.
    static func newlyEarned(restaurants: [Restaurant]) -> [Badge] {
        let all = badges(restaurants: restaurants)
        let earnedNow = all.filter(\.earned)

        let defaults = UserDefaults.standard
        let previous = Set(defaults.stringArray(forKey: earnedIDsKey) ?? [])
        let fresh = earnedNow.filter { !previous.contains($0.id) }

        let union = previous.union(earnedNow.map(\.id))
        // Persist in catalog order (plus any unknown legacy IDs) for stability.
        let ordered = catalog.map(\.id).filter { union.contains($0) }
        let legacy = union.subtracting(ordered).sorted()
        defaults.set(ordered + legacy, forKey: earnedIDsKey)

        return fresh
    }
}
