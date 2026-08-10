import CoreLocation
import Foundation
import FoundationModels
import MapKit

// MARK: - Taste types

/// A distilled picture of what the user actually eats, computed from the collection.
struct TasteProfile {
    /// Sorted by plate count, descending.
    var topCuisines: [CuisineCount]
    /// Starred plates / total plates, 0...1.
    var michelinAffinity: Double
    /// Bib Gourmand plates / total plates, 0...1.
    var bibAffinity: Double
    var avgPerVisitHome: Decimal
    /// Top 5 dishes across all visits.
    var favoriteDishes: [DishCount]
    var distinctCuisines: Int
    var plateCount: Int
}

/// A city-level result from the destination search.
struct CityMatch: Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var country: String
    var latitude: Double
    var longitude: Double
}

/// One personalized restaurant suggestion for a chosen city.
struct Recommendation: Identifiable {
    var id: UUID = UUID()
    var name: String
    /// Display hint, e.g. "Sushi" or a `Cuisine` display name.
    var cuisineText: String
    var cuisineEmoji: String
    /// 0 = not starred.
    var stars: Int
    var isBibGourmand: Bool
    var latitude: Double
    var longitude: Double
    var address: String
    /// Personalized one-liner. Never empty.
    var reason: String
    var alreadyCollected: Bool
    var score: Double
}

// MARK: - TasteEngine

/// Learns a taste profile from the collection and turns it into personalized
/// recommendations for any city: Michelin Guide records first, Apple Maps
/// searches for variety, scored against the profile, with reasons written by
/// the on-device model (deterministic templates as the always-works fallback).
enum TasteEngine {

    // MARK: - Profile

    static func profile(restaurants: [Restaurant]) -> TasteProfile {
        var cuisineTally: [Cuisine: Int] = [:]
        var dishTally: [String: Int] = [:]
        var visitCount = 0
        var totalSpend = Decimal(0)
        var starredPlates = 0
        var bibPlates = 0

        for restaurant in restaurants {
            cuisineTally[restaurant.cuisine, default: 0] += 1
            if restaurant.michelinStars > 0 { starredPlates += 1 }
            if restaurant.isBibGourmand { bibPlates += 1 }
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

        let topCuisines = cuisineTally
            .map { CuisineCount(cuisine: $0.key, count: $0.value) }
            .sorted {
                $0.count != $1.count
                    ? $0.count > $1.count
                    : $0.cuisine.rawValue < $1.cuisine.rawValue
            }

        let favoriteDishes = dishTally
            .map { DishCount(name: $0.key.capitalized, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
            .prefix(5)

        let plateCount = restaurants.count
        let average: Decimal = visitCount > 0 ? totalSpend / Decimal(visitCount) : 0

        return TasteProfile(topCuisines: topCuisines,
                            michelinAffinity: plateCount > 0 ? Double(starredPlates) / Double(plateCount) : 0,
                            bibAffinity: plateCount > 0 ? Double(bibPlates) / Double(plateCount) : 0,
                            avgPerVisitHome: average,
                            favoriteDishes: Array(favoriteDishes),
                            distinctCuisines: cuisineTally.count,
                            plateCount: plateCount)
    }

    #if DEBUG
    /// Accumulates city-search diagnostics for headless debugging; the debug
    /// launch hook writes this to Documents/debug_cities.txt.
    nonisolated(unsafe) static var cityDebugLog = ""
    #endif

    private static func cityDebug(_ line: String) {
        #if DEBUG
        cityDebugLog += line + "\n"
        #endif
    }

    // MARK: - City search

    /// City-level MKLocalSearch: natural query, locality placemarks only,
    /// deduped by name+country, capped at 6. Never throws — [] on any failure.
    static func searchCities(_ query: String) async -> [CityMatch] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        #if DEBUG
        cityDebugLog = ""
        #endif

        var seen = Set<String>()
        var matches: [CityMatch] = []
        func add(locality: String, country: String, coordinate: CLLocationCoordinate2D) {
            let key = locality.lowercased() + "|" + country.lowercased()
            guard seen.insert(key).inserted else { return }
            matches.append(CityMatch(name: locality,
                                     country: country,
                                     latitude: coordinate.latitude,
                                     longitude: coordinate.longitude))
        }

        // CLGeocoder is the canonical resolver for "a city by name" and is not
        // biased toward the device region the way MKLocalSearch ranking is
        // ("Tokyo" must resolve to Tokyo, Japan — not Tokio, US).
        do {
            let placemarks = try await CLGeocoder().geocodeAddressString(trimmed)
            cityDebug("geocoder returned \(placemarks.count) placemarks")
            for p in placemarks {
                cityDebug("geocoder: locality=\(p.locality ?? "nil") country=\(p.country ?? "nil") name=\(p.name ?? "nil")")
                // City-scale places aren't always "localities": Tokyo geocodes as
                // a prefecture (locality nil, name "Tokyo"), Hong Kong/Singapore
                // as regions. Fall back through the coarser fields.
                let cityName = p.locality ?? p.subAdministrativeArea ?? p.administrativeArea ?? p.name
                guard let cityName, !cityName.isEmpty, let location = p.location else { continue }
                add(locality: cityName, country: p.country ?? "", coordinate: location.coordinate)
            }
        } catch {
            cityDebug("geocoder error: \(error)")
        }

        // MKLocalSearch backfills alternatives for ambiguous names.
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = .address
        request.addressFilter = MKAddressFilter(including: .locality)
        request.region = MKCoordinateRegion(.world)
        if let response = try? await MKLocalSearch(request: request).start() {
            for item in response.mapItems {
                let placemark = item.placemark
                guard let locality = placemark.locality ?? item.name,
                      !locality.isEmpty else { continue }
                add(locality: locality,
                    country: placemark.country ?? "",
                    coordinate: placemark.coordinate)
            }
        }
        // MapKit's order is biased toward the device region, which can rank an
        // obscure near-match (Tokio, US) above the city the user means (Tokyo).
        // Re-rank by name-match quality, keeping MapKit's order within a tier.
        func tier(_ match: CityMatch) -> Int {
            let name = normalized(match.name)
            let wanted = normalized(trimmed)
            if name == wanted { return 0 }
            if name.hasPrefix(wanted) { return 1 }
            return 2
        }
        return matches.enumerated()
            .sorted { (tier($0.element), $0.offset) < (tier($1.element), $1.offset) }
            .prefix(6)
            .map(\.element)
    }

    // MARK: - Recommendations

    /// Candidates within this radius of the city center are considered.
    private static let candidateRadiusMeters: CLLocationDistance = 40_000
    /// Fuzzy "same place" distance for the already-collected check.
    private static let collectedRadiusMeters: CLLocationDistance = 150

    static func recommend(in city: CityMatch,
                          profile: TasteProfile,
                          existing: [Restaurant]) async -> [Recommendation] {
        let center = CLLocation(latitude: city.latitude, longitude: city.longitude)
        let topThree = Array(profile.topCuisines.prefix(3))

        // 1. Michelin Guide candidates near the city.
        var candidates: [Candidate] = []
        for record in MichelinCatalog.all {
            let location = CLLocation(latitude: record.latitude, longitude: record.longitude)
            guard center.distance(from: location) <= candidateRadiusMeters else { continue }
            candidates.append(michelinCandidate(record, topThree: topThree, profile: profile))
        }
        if Task.isCancelled { return [] }

        // 2. Apple Maps candidates for the top-3 cuisines, searched concurrently.
        let center2D = CLLocationCoordinate2D(latitude: city.latitude, longitude: city.longitude)
        let appleBatches = await withTaskGroup(of: (Cuisine, Int, [PlaceMatch]).self) { group in
            for entry in topThree {
                group.addTask {
                    let matches = await PlaceMatcher.search(query: "\(entry.cuisine.displayName) restaurant",
                                                            near: center2D)
                    return (entry.cuisine, entry.count, matches)
                }
            }
            var batches: [(Cuisine, Int, [PlaceMatch])] = []
            for await batch in group { batches.append(batch) }
            return batches
        }
        if Task.isCancelled { return [] }

        for (cuisine, count, matches) in appleBatches {
            for match in matches.prefix(5) {
                if let candidate = appleCandidate(match, cuisine: cuisine, cuisineCount: count) {
                    candidates.append(candidate)
                }
            }
        }

        // 3. Merge: best score first, then dedupe by normalized name so the
        //    strongest duplicate (usually the Michelin record) survives.
        var seen = Set<String>()
        var unique: [Candidate] = []
        for candidate in candidates.sorted(by: { $0.score > $1.score }) {
            let key = normalized(candidate.name)
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            unique.append(candidate)
        }
        var final = Array(unique.prefix(12))
        guard !final.isEmpty else { return [] }

        // Collected places stay in — just marked, never excluded.
        let collected = existing.map {
            (name: normalized($0.name),
             location: CLLocation(latitude: $0.latitude, longitude: $0.longitude))
        }
        for index in final.indices {
            final[index].alreadyCollected = isCollected(final[index], among: collected)
        }
        if Task.isCancelled { return [] }

        // 4. Reasons — model when available, templates otherwise; never empty.
        let reasons = await reasons(profile: profile, candidates: final)

        return final.enumerated().map { index, candidate in
            Recommendation(name: candidate.name,
                           cuisineText: candidate.cuisineText,
                           cuisineEmoji: candidate.cuisineEmoji,
                           stars: candidate.stars,
                           isBibGourmand: candidate.isBib,
                           latitude: candidate.latitude,
                           longitude: candidate.longitude,
                           address: candidate.address,
                           reason: reasons[index],
                           alreadyCollected: candidate.alreadyCollected,
                           score: candidate.score)
        }
    }

    // MARK: - Candidates & scoring

    private struct Candidate {
        var name: String
        var cuisine: Cuisine?
        var cuisineText: String
        var cuisineEmoji: String
        var stars: Int
        var isBib: Bool
        var latitude: Double
        var longitude: Double
        var address: String
        var score: Double
        /// Plate count of the matched top-3 cuisine; 0 when no cuisine match.
        var matchedCuisineCount: Int
        var alreadyCollected = false
    }

    private static func michelinCandidate(_ record: MichelinRecord,
                                          topThree: [CuisineCount],
                                          profile: TasteProfile) -> Candidate {
        let hint = (record.cuisine ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let mapped = cuisine(fromHint: hint)

        var score = 0.0
        var matchedCount = 0
        if let mapped, let match = topThree.first(where: { $0.cuisine == mapped }) {
            score += 2.5
            matchedCount = match.count
        }
        if record.stars > 0 {
            score += Double(record.stars) * (1 + 2 * profile.michelinAffinity)
        } else {
            // In the catalog, 0 stars means Bib Gourmand.
            score += 1.5 * (1 + profile.bibAffinity)
        }
        if profile.avgPerVisitHome < 40, record.stars >= 2 {
            // Probably fancier than their usual spend — rank lower, never exclude.
            score -= 1.0
        }

        return Candidate(name: record.name,
                         cuisine: mapped,
                         cuisineText: hint.isEmpty ? (mapped?.displayName ?? "Tasting menu") : hint.capitalized,
                         cuisineEmoji: (mapped ?? .other).emoji,
                         stars: max(0, record.stars),
                         isBib: record.stars == 0,
                         latitude: record.latitude,
                         longitude: record.longitude,
                         address: [record.city, record.country]
                             .filter { !$0.isEmpty }
                             .joined(separator: ", "),
                         score: score,
                         matchedCuisineCount: matchedCount)
    }

    private static func appleCandidate(_ match: PlaceMatch,
                                       cuisine: Cuisine,
                                       cuisineCount: Int) -> Candidate? {
        guard let distance = match.distanceMeters,
              distance <= candidateRadiusMeters else { return nil }

        // Came out of a top-cuisine search, so it starts with the cuisine-match
        // credit, then decays with distance from the city center.
        var score = 2.5
        score += 1.5 * max(0, 1 - distance / candidateRadiusMeters)

        let fallbackAddress = [match.city, match.country]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        return Candidate(name: match.name,
                         cuisine: cuisine,
                         cuisineText: cuisine.displayName,
                         cuisineEmoji: cuisine.emoji,
                         stars: 0,
                         isBib: false,
                         latitude: match.latitude,
                         longitude: match.longitude,
                         address: match.address.isEmpty ? fallbackAddress : match.address,
                         score: score,
                         matchedCuisineCount: cuisineCount)
    }

    /// Fuzzy name (equality or containment, normalized) within ~150 m.
    private static func isCollected(_ candidate: Candidate,
                                    among collected: [(name: String, location: CLLocation)]) -> Bool {
        let key = normalized(candidate.name)
        guard !key.isEmpty else { return false }
        let location = CLLocation(latitude: candidate.latitude, longitude: candidate.longitude)
        return collected.contains { entry in
            guard !entry.name.isEmpty else { return false }
            let sameName = entry.name == key
                || entry.name.contains(key)
                || key.contains(entry.name)
            return sameName && entry.location.distance(from: location) <= collectedRadiusMeters
        }
    }

    // MARK: - Cuisine hint mapping

    /// Maps a free-form Michelin cuisine hint ("Sushi", "Modern French", …) to
    /// the app's `Cuisine`. Ordered so specific keywords win over broad ones.
    private static let hintMap: [(cuisine: Cuisine, keywords: [String])] = [
        (.ramen, ["ramen"]),
        (.japanese, ["sushi", "omakase", "kaiseki", "izakaya", "tempura", "teppanyaki",
                     "yakitori", "japanese"]),
        (.pizza, ["pizza", "pizzeria"]),
        (.italian, ["italian", "tuscan", "piedmont", "sicilian"]),
        (.french, ["french", "provencal", "alsatian"]),
        (.chinese, ["cantonese", "sichuan", "szechuan", "hunan", "shanghainese",
                    "dim sum", "taiwanese", "chinese", "dumpling", "noodle"]),
        (.korean, ["korean"]),
        (.thai, ["thai"]),
        (.vietnamese, ["vietnamese"]),
        (.indian, ["indian"]),
        (.mexican, ["mexican", "taqueria", "taco"]),
        (.spanish, ["spanish", "basque", "catalan", "tapas", "galician"]),
        (.greek, ["greek"]),
        (.middleEastern, ["lebanese", "turkish", "israeli", "moroccan", "persian",
                          "middle eastern"]),
        (.mediterranean, ["mediterranean"]),
        (.seafood, ["seafood", "fish", "shellfish", "oyster"]),
        (.steakhouse, ["steakhouse", "steak", "meats and grills", "grills"]),
        (.bbq, ["barbecue", "bbq", "smokehouse"]),
        (.vegetarian, ["vegetarian", "vegan", "plant"]),
        (.german, ["german", "austrian"]),
        (.american, ["american", "californian"]),
        (.fusion, ["creative", "innovative", "modern cuisine", "contemporary", "fusion"])
    ]

    private static func cuisine(fromHint hint: String) -> Cuisine? {
        let lowered = hint
            .folding(options: [.diacriticInsensitive, .caseInsensitive],
                     locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        guard !lowered.isEmpty else { return nil }
        for entry in hintMap {
            for keyword in entry.keywords where lowered.contains(keyword) {
                return entry.cuisine
            }
        }
        return nil
    }

    // MARK: - Reasons

    private static func reasons(profile: TasteProfile, candidates: [Candidate]) async -> [String] {
        let modeled = await modelReasons(profile: profile, candidates: candidates) ?? [:]
        return candidates.indices.map { index in
            if let reason = modeled[index], !reason.isEmpty { return reason }
            return fallbackReason(for: candidates[index], profile: profile, index: index)
        }
    }

    private struct ReasonTimeout: Error {}

    /// One batched prompt for every candidate; strict numbered-line output,
    /// parsed defensively. Nil on any failure — the caller falls back per line.
    private static func modelReasons(profile: TasteProfile,
                                     candidates: [Candidate]) async -> [Int: String]? {
        guard !candidates.isEmpty,
              SystemLanguageModel.default.availability == .available else { return nil }

        let instructions = """
        You write short personalized reasons to visit recommended restaurants. \
        Reply with exactly one line per numbered candidate, in order, formatted \
        "1. reason" — no other text. Each reason is 12 words or fewer, in second \
        person, and grounded in the diner's actual history.
        """

        let starredPlates = Int((profile.michelinAffinity * Double(profile.plateCount)).rounded())
        let bibPlates = Int((profile.bibAffinity * Double(profile.plateCount)).rounded())
        let cuisineLine = profile.topCuisines.prefix(3)
            .map { "\($0.cuisine.displayName) ×\($0.count)" }
            .joined(separator: ", ")

        var prompt = "Diner history:\n"
        prompt += "- Top cuisines: \(cuisineLine.isEmpty ? "none yet" : cuisineLine)\n"
        prompt += "- \(profile.plateCount) restaurants collected, "
        prompt += "\(starredPlates) Michelin-starred, \(bibPlates) Bib Gourmand\n"
        if profile.avgPerVisitHome > 0 {
            prompt += "- Average spend per visit: \(plMoney(profile.avgPerVisitHome, CurrencyConverter.homeCurrency))\n"
        }
        if !profile.favoriteDishes.isEmpty {
            prompt += "- Favorite dishes: \(profile.favoriteDishes.prefix(3).map(\.name).joined(separator: ", "))\n"
        }
        prompt += "\nCandidates:\n"
        for (index, candidate) in candidates.enumerated() {
            var line = "\(index + 1). \(candidate.name) — \(candidate.cuisineText)"
            if candidate.stars > 0 {
                line += ", \(candidate.stars) Michelin star\(candidate.stars == 1 ? "" : "s")"
            } else if candidate.isBib {
                line += ", Bib Gourmand"
            }
            prompt += line + "\n"
        }
        prompt += "\nOne reason per candidate:"

        do {
            let reply: String = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    let session = LanguageModelSession(instructions: instructions)
                    return try await session.respond(to: prompt).content
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(6))
                    throw ReasonTimeout()
                }
                guard let first = try await group.next() else { throw ReasonTimeout() }
                group.cancelAll()
                return first
            }
            let parsed = parseReasonLines(reply, count: candidates.count)
            return parsed.isEmpty ? nil : parsed
        } catch {
            return nil
        }
    }

    /// Accepts "1. reason", "1) reason", "1: reason", "1 - reason"; strips
    /// quotes, caps runaway lines, ignores anything out of range.
    private static func parseReasonLines(_ reply: String, count: Int) -> [Int: String] {
        var reasons: [Int: String] = [:]
        for rawLine in reply.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            let digits = line.prefix(while: \.isNumber)
            guard !digits.isEmpty,
                  let number = Int(digits),
                  (1...count).contains(number) else { continue }

            var rest = line.dropFirst(digits.count)
            while let first = rest.first,
                  first == "." || first == ")" || first == ":" || first == "-" || first == " " {
                rest = rest.dropFirst()
            }
            var reason = rest.trimmingCharacters(in: CharacterSet(charactersIn: "\"“”'` "))
            let words = reason.split(separator: " ")
            if words.count > 14 {
                reason = words.prefix(14).joined(separator: " ") + "…"
            }
            guard !reason.isEmpty else { continue }
            reasons[number - 1] = reason
        }
        return reasons
    }

    /// Deterministic template reasons built from the match evidence, with
    /// variants rotated by rank so a fallback list doesn't read copy-pasted.
    private static func fallbackReason(for candidate: Candidate,
                                       profile: TasteProfile,
                                       index: Int) -> String {
        let cuisineName = candidate.cuisine?.displayName ?? candidate.cuisineText

        if candidate.stars > 0, candidate.matchedCuisineCount > 0 {
            return "Your \(ordinal(candidate.matchedCuisineCount + 1)) \(cuisineName) plate — this one has \(starPhrase(candidate.stars))"
        }
        if candidate.stars > 0 {
            let variants: [String] = profile.michelinAffinity > 0
                ? ["\(starTitle(candidate.stars)), and you clearly chase them",
                   "\(starTitle(candidate.stars)) — right in your Michelin lane",
                   "Another \(starPhrase(candidate.stars)) for your collection"]
                : ["\(starTitle(candidate.stars)) — it could be your first Michelin plate",
                   "\(starTitle(candidate.stars)), waiting to start your Michelin run"]
            return variants[index % variants.count]
        }
        if candidate.isBib {
            let variants = ["Bib Gourmand: big flavor, gentle bill — very you",
                            "A Bib Gourmand find — serious cooking, friendly prices",
                            "Michelin's best-value pick here, and it suits you"]
            return variants[index % variants.count]
        }
        if candidate.matchedCuisineCount > 0 {
            let count = candidate.matchedCuisineCount
            let plates = count == 1 ? "1 \(cuisineName) plate" : "\(count) \(cuisineName) plates"
            let variants = ["You've collected \(plates) — this one's a local icon",
                            "\(plates) in, and this one calls your name",
                            "More \(cuisineName)? Your collection says yes"]
            return variants[index % variants.count]
        }
        let variants = ["Something new for this corner of your globe",
                        "A local favorite — sounds like your kind of table",
                        "Fresh cuisine, fresh plate — worth the detour"]
        return variants[index % variants.count]
    }

    private static func ordinal(_ number: Int) -> String {
        let words = [1: "first", 2: "second", 3: "third", 4: "fourth", 5: "fifth",
                     6: "sixth", 7: "seventh", 8: "eighth", 9: "ninth", 10: "tenth"]
        if let word = words[number] { return word }
        switch number % 10 {
        case 1 where number % 100 != 11: return "\(number)st"
        case 2 where number % 100 != 12: return "\(number)nd"
        case 3 where number % 100 != 13: return "\(number)rd"
        default: return "\(number)th"
        }
    }

    private static func starPhrase(_ stars: Int) -> String {
        switch stars {
        case 1: return "a star"
        case 2: return "two stars"
        default: return "three stars"
        }
    }

    private static func starTitle(_ stars: Int) -> String {
        switch stars {
        case 1: return "One star"
        case 2: return "Two stars"
        default: return "Three stars"
        }
    }

    // MARK: - Normalization

    /// Lowercased, diacritics stripped, alphanumerics only — for name dedupe
    /// and the collected check.
    private static func normalized(_ name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                  locale: Locale(identifier: "en_US_POSIX"))
        let scalars = folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        return String(String.UnicodeScalarView(scalars)).lowercased()
    }

    /// Lowercases, trims, strips quantity prefixes ("2x ", "x2 ", "2 ") and
    /// collapses whitespace — mirrors the app-wide favorite-dish semantics.
    private static func normalizedDishName(_ raw: String) -> String {
        var name = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let quantityPrefixes = [
            "^\\d+\\s*[x×]\\s*",
            "^[x×]\\s*\\d+\\s+",
            "^\\d+\\s+"
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
}
