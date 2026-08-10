import Foundation
import FoundationModels

/// Classifies a restaurant into a `Cuisine`.
///
/// Primary path: the on-device Apple Foundation Model (when available) is asked to
/// pick exactly one identifier from `Cuisine.allCases`. Any failure — unavailability,
/// guardrail refusal, unparseable reply, or a 6-second timeout — falls through to a
/// fast keyword heuristic over the restaurant name, dish names, and POI hint.
enum CuisineClassifier {

    static func classify(restaurantName: String, dishNames: [String], poiHint: String?) async -> Cuisine {
        let dishes = dishNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if SystemLanguageModel.default.availability == .available,
           let modelAnswer = await modelClassify(restaurantName: restaurantName,
                                                 dishNames: dishes,
                                                 poiHint: poiHint) {
            return modelAnswer
        }
        return heuristicClassify(restaurantName: restaurantName,
                                 dishNames: dishes,
                                 poiHint: poiHint)
    }

    // MARK: - Foundation model path

    private struct ClassificationTimeout: Error {}

    private static func modelClassify(restaurantName: String,
                                      dishNames: [String],
                                      poiHint: String?) async -> Cuisine? {
        let identifiers = Cuisine.allCases.map(\.rawValue).joined(separator: ", ")
        let instructions = """
        You label restaurants with a cuisine category. \
        Reply with exactly one identifier from this list and nothing else: \(identifiers).
        """

        var prompt = "Restaurant: \(restaurantName)"
        if !dishNames.isEmpty {
            prompt += "\nDishes: \(dishNames.prefix(12).joined(separator: ", "))"
        }
        if let poiHint, !poiHint.isEmpty {
            prompt += "\nPlace category: \(poiHint)"
        }
        prompt += "\nCuisine identifier:"

        do {
            let reply: String = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    let session = LanguageModelSession(instructions: instructions)
                    return try await session.respond(to: prompt).content
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(6))
                    throw ClassificationTimeout()
                }
                guard let first = try await group.next() else { throw ClassificationTimeout() }
                group.cancelAll()
                return first
            }
            return parseModelReply(reply)
        } catch {
            return nil
        }
    }

    /// Accepts an exact identifier (trimmed, case-insensitive), or a reply that
    /// contains exactly one valid identifier anywhere in its text.
    private static func parseModelReply(_ reply: String) -> Cuisine? {
        let strippable = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
            .union(.symbols)
        let cleaned = reply.trimmingCharacters(in: strippable).lowercased()
        guard !cleaned.isEmpty else { return nil }

        if let exact = Cuisine.allCases.first(where: { $0.rawValue.lowercased() == cleaned }) {
            return exact
        }
        let contained = Cuisine.allCases.filter { cleaned.contains($0.rawValue.lowercased()) }
        return contained.count == 1 ? contained[0] : nil
    }

    // MARK: - Keyword heuristic path

    /// Ordered so earlier entries win score ties. Single-word keywords match whole
    /// tokens (with plural and long-prefix tolerance); phrases match on word
    /// boundaries. All matching is case- and diacritic-insensitive.
    private static let keywordMap: [(cuisine: Cuisine, keywords: [String])] = [
        (.japanese, ["sushi", "omakase", "izakaya", "yakitori", "tempura", "kaiseki"]),
        (.ramen, ["ramen"]),
        (.italian, ["trattoria", "osteria", "cucina"]),
        (.pizza, ["pizzeria", "pizza"]),
        (.mexican, ["taqueria", "cantina", "taco"]),
        (.bbq, ["bbq", "smokehouse", "barbecue"]),
        (.steakhouse, ["steakhouse", "chophouse", "grill house"]),
        (.seafood, ["oyster", "lobster", "crab", "fish", "seafood"]),
        (.bakery, ["boulangerie", "patisserie", "bakery", "croissant"]),
        (.french, ["bistro", "brasserie", "maison"]),
        (.vietnamese, ["pho", "banh mi"]),
        (.thai, ["thai", "som tam", "pad thai"]),
        (.chinese, ["dim sum", "szechuan", "sichuan", "hunan", "cantonese", "noodle house", "dumpling"]),
        (.indian, ["curry", "masala", "tandoor", "biryani"]),
        (.middleEastern, ["kebab", "falafel", "shawarma", "mezze"]),
        (.greek, ["taverna", "gyro", "souvlaki"]),
        (.spanish, ["tapas", "paella"]),
        (.burgers, ["burger"]),
        (.cafe, ["coffee", "cafe", "espresso", "roasters"]),
        (.bar, ["wine bar", "cocktail", "taproom", "brewery"]),
        (.korean, ["kbbq", "korean", "bibimbap", "kimchi"]),
        (.american, ["deli", "diner"])
    ]

    private static func heuristicClassify(restaurantName: String,
                                          dishNames: [String],
                                          poiHint: String?) -> Cuisine {
        var scores: [Cuisine: Int] = [:]

        // Dish names count exactly as strongly as the restaurant name.
        for source in [restaurantName] + dishNames {
            let tokens = tokenize(source)
            guard !tokens.isEmpty else { continue }
            let padded = " " + tokens.joined(separator: " ") + " "
            for entry in keywordMap {
                for keyword in entry.keywords where matches(keyword, tokens: tokens, padded: padded) {
                    scores[entry.cuisine, default: 0] += 1
                }
            }
        }

        var best: (cuisine: Cuisine, score: Int)?
        for entry in keywordMap {
            let score = scores[entry.cuisine] ?? 0
            if score > (best?.score ?? 0) { best = (entry.cuisine, score) }
        }
        if let best { return best.cuisine }

        if let poiHint {
            let hint = poiHint.lowercased()
            if hint.contains("cafe") { return .cafe }
            if hint.contains("bakery") { return .bakery }
            if hint.contains("brewery") || hint.contains("winery") || hint.contains("nightlife") {
                return .bar
            }
        }
        return .other
    }

    /// Lowercases, strips diacritics, and splits on anything non-alphanumeric.
    private static func tokenize(_ text: String) -> [String] {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                  locale: Locale(identifier: "en_US"))
        let spaced = String(folded.map { $0.isLetter || $0.isNumber ? $0 : " " }).lowercased()
        return spaced.split(separator: " ").map(String.init)
    }

    /// Word-boundary matching: exact token, simple plural, or — for keywords of five
    /// or more characters — a token prefix (so "tandoor" hits "tandoori" while short
    /// keywords like "deli" never hit "delicious"). Phrases match padded substrings.
    private static func matches(_ keyword: String, tokens: [String], padded: String) -> Bool {
        if keyword.contains(" ") {
            return padded.contains(" \(keyword) ") || padded.contains(" \(keyword)s ")
        }
        return tokens.contains { token in
            token == keyword
                || token == keyword + "s"
                || (keyword.count >= 5 && token.hasPrefix(keyword))
        }
    }
}
