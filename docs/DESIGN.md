# Plates — Design & Contracts

Plates is a Pokédex for restaurants. You collect a restaurant ("a plate") by scanning
its receipt — the receipt is proof you were really there. Your collection lives on a
dark world globe that lights up point by point. Michelin restaurants are rare spawns
whose stars accumulate into a lifetime star count.

Decisions (locked):
- Name **Plates**, bundle `com.dxzhang.plates`, iPhone-only, portrait, iOS 26 minimum.
- **Free + Pro**: 10 restaurants free, then one-time Pro unlock (`com.dxzhang.plates.pro`, $6.99).
- **On-device only**: Vision OCR + FoundationModels (with keyword fallback). No backend, no accounts.
- v1 includes: food photos, shareable cards, widgets, streaks & badges.

## Design language

The app is **always dark** (`.preferredColorScheme(.dark)` is set at the root).

- Colors — use ONLY the `Color.pl*` tokens from `Plates/Core/Theme/Theme.swift`:
  `plBackground` (screen bg), `plSurface` / `plSurfaceElevated` (cards), `plStroke`
  (hairlines), `plGold` / `plGoldDeep` + `LinearGradient.plGold` (the precious-metal
  accent — reserved for collected things, money moments, CTAs), `plMichelin` (red —
  ONLY for Michelin content), `plText`, `plTextSecondary`.
- Type — `.plDisplay(size)` (serif) for restaurant names and hero headers;
  `.plNumber(size)` (rounded) for money and counts; system sans for body/labels.
- Surfaces — `.plCard()` for cards; corner radius 22 (cards) / 14 (small chips).
- Glow — `.plGlow()` sparingly: lit map points, the capture FAB, celebration moments.
- Cuisine is always shown as `cuisine.emoji` + `cuisine.displayName`.
- Money via `plMoney(amount, code)`. Screens use generous spacing (16/20), no clutter.
- Haptics: `Haptics.tap()` on taps, `.success()` on saves, `.celebrate()` on big moments.
- Every list/screen needs a designed empty state (icon, one-liner, gentle CTA).

## Architecture

- SwiftUI + SwiftData, local-first. Images on disk via `ImageStore`, models store file names.
- Xcode project uses filesystem-synchronized groups: **any file you create under
  `Plates/` or `PlatesWidgets/` is automatically in that target.** Never edit
  `project.pbxproj`, `Config/`, or another feature's folder.
- Two targets: app (`Plates/`) and widget extension (`PlatesWidgets/`). The widget
  target CANNOT import app code — it reads a JSON snapshot from the App Group
  (`group.com.dxzhang.plates`, file `snapshot.json`) and duplicates the small
  `WidgetSnapshot` struct.
- Apple frameworks only. No SPM packages. Swift 5 language mode, iOS 26 SDK.

## Shared types (already implemented — read `Core/Models/Models.swift`)

`Restaurant`, `Visit` (SwiftData), `Cuisine`, `ParsedReceipt`, `ParsedLineItem`,
`PlaceMatch`, `MichelinRecord`, `YearStats`, `LifetimeStats`, `CuisineAmount`,
`CuisineCount`, `NamedAmount`, `DishCount`, `Badge`, `BadgeTier`, `WidgetSnapshot`.
Also `ImageStore`, `Theme`, `plMoney`, `Haptics`, `Decimal.plDouble`.

## Service contracts (each lives in `Plates/Core/Services/<Name>.swift`)

Implement EXACTLY these signatures — feature code is written against them.

```swift
enum ReceiptParser {
    /// OCR + heuristics over one or more receipt page images.
    static func parse(images: [UIImage]) async -> ParsedReceipt
}

enum PlaceMatcher {
    /// MKLocalSearch (restaurant/café POIs preferred). Global search seeded by
    /// `query`; ranked by distance when `near` is provided. Fills city/country
    /// / countryCode from placemarks.
    static func search(query: String, near: CLLocationCoordinate2D?) async -> [PlaceMatch]
}

@Observable final class LocationProvider: NSObject, CLLocationManagerDelegate {
    static let shared: LocationProvider
    var lastCoordinate: CLLocationCoordinate2D? { get }
    /// Requests when-in-use permission if needed and refreshes a one-shot location.
    func request()
}

enum MichelinCatalog {
    static var all: [MichelinRecord] { get }   // lazy-loaded from Resources/michelin.json
    /// Fuzzy name match (normalized: lowercased, diacritics stripped, filler words
    /// dropped) within ~60 km of `near` when provided.
    static func match(name: String, near: CLLocationCoordinate2D?) -> MichelinRecord?
}

enum CuisineClassifier {
    /// FoundationModels when available, else keyword heuristics over name/dishes/POI hint.
    static func classify(restaurantName: String, dishNames: [String], poiHint: String?) async -> Cuisine
}

@Observable final class StoreService {          // StoreKit 2
    static let shared: StoreService
    static let freeRestaurantLimit: Int         // 10
    var isPro: Bool { get }
    var proProduct: Product? { get }
    var priceText: String { get }               // "$6.99" fallback if product not loaded
    func canAddRestaurant(currentCount: Int) -> Bool
    func start() async                          // load product, listen for transactions
    func purchasePro() async throws -> Bool
    func restorePurchases() async
}

enum CurrencyConverter {
    /// UserDefaults key "homeCurrency"; defaults to Locale.current.currency ?? "USD".
    static var homeCurrency: String { get set }
    /// Via Resources/currency_rates.json (USD base). Identity for unknown codes.
    static func toHome(_ amount: Decimal, from code: String) -> Decimal
    static func symbol(for code: String) -> String
    static var supportedCurrencies: [String] { get }   // sorted, from the rates file
}

enum StatsEngine {
    static func yearStats(year: Int, restaurants: [Restaurant]) -> YearStats
    static func lifetime(restaurants: [Restaurant]) -> LifetimeStats
    static func availableYears(restaurants: [Restaurant]) -> [Int]  // desc, always incl. current
}

enum BadgeEngine {
    static func badges(restaurants: [Restaurant]) -> [Badge]
    /// Diffs against the persisted earned-ID set (UserDefaults), persists, returns
    /// only the badges earned since last call. Call after each save.
    static func newlyEarned(restaurants: [Restaurant]) -> [Badge]
}

enum WidgetSnapshotWriter {
    static let appGroupID: String               // "group.com.dxzhang.plates"
    /// Encodes WidgetSnapshot (current-year spend, home currency) to
    /// <appGroup>/snapshot.json and calls WidgetCenter.reloadAllTimelines().
    static func write(restaurants: [Restaurant])
}
```

Semantics:
- **Stars collected** = sum of `michelinStars` across *distinct* Michelin restaurants
  in the collection (visits don't multiply stars).
- **Streak** = consecutive calendar months with ≥1 *new* restaurant (`addedAt`),
  counting back from the current month; if the current month is empty, count from
  last month (grace) — current month simply isn't added yet.
- **Favorite dishes** from `Visit.lineItems` names, normalized (lowercased, trimmed,
  qty prefixes like "2x" stripped), counted across all visits.

## Feature contracts (top-level views, `Plates/Features/<Name>/`)

```swift
struct GlobeView: View { init() }                       // Features/Globe
struct CollectionView: View { init() }                  // Features/Collection
struct StatsView: View { init() }                       // Features/Stats
struct PassportView: View { init() }                    // Features/Passport
struct CaptureFlowView: View { init() }                 // Features/Capture (fullScreenCover)
struct OnboardingView: View { init(onDone: @escaping () -> Void) }  // Features/Onboarding
struct PaywallView: View { init() }                     // Features/Paywall (sheet)
```

All read SwiftData via `@Query` / `@Environment(\.modelContext)` and get
`StoreService` via `@Environment(StoreService.self)` (injected at root).

Cross-feature coordination:
- After saving a **new** restaurant, Capture sets
  `UserDefaults.standard.set(restaurant.id.uuidString, forKey: "pendingSpotlightID")`.
  RootView switches to the Globe tab on dismiss; GlobeView (onAppear + onChange)
  flies to that restaurant, plays the light-up bloom, then clears the key.
- Capture gates NEW restaurants (not repeat visits) with
  `store.canAddRestaurant(currentCount:)`; on failure it presents `PaywallView`
  as a sheet and only saves once `isPro` or under the limit.
- After any save, Capture calls `BadgeEngine.newlyEarned` and shows unlocked badges
  in its celebration, then `WidgetSnapshotWriter.write`.

## Capture flow (the product's heart)

scan → parse → confirm → celebrate:
1. Full-screen VisionKit `VNDocumentCameraViewController` wrapper. Also offer
   "Enter manually" (skips OCR) — required for simulator testing and broken receipts.
2. Parsing overlay (gold shimmer, "Reading your receipt…").
3. Confirm screen: receipt thumbnail; editable merchant/date/total/currency;
   place picker seeded with `PlaceMatcher.search(query: merchant, near: location)`
   (tappable candidates + manual search field); duplicate detection — if a match is
   ~the same place as an existing Restaurant (name-normalized + <150 m), this
   becomes a repeat visit to it ("Visit #3 to …"); Michelin auto-match badge shown
   when `MichelinCatalog.match` hits; cuisine pre-filled via `CuisineClassifier`,
   user-overridable picker.
4. Celebration: gold plate bloom + name; for Michelin, star-burst with
   `plMichelin` accents and "★×N collected"; newly earned badges slide in.
   Then dismiss (RootView hands off to the Globe for the map light-up).

## Ownership map (for parallel work — stay strictly inside your paths)

| Agent | Writes |
|---|---|
| S1 | `Core/Services/ReceiptParser.swift` |
| S2 | `Core/Services/PlaceMatcher.swift` (incl. LocationProvider) |
| S3 | `Core/Services/MichelinCatalog.swift`, `Resources/michelin.json` |
| S4 | `Core/Services/CuisineClassifier.swift` |
| S5 | `Core/Services/StoreService.swift` |
| S6 | `Core/Services/CurrencyConverter.swift`, `Core/Services/StatsEngine.swift` |
| S7 | `Core/Services/BadgeEngine.swift`, `Core/Services/WidgetSnapshotWriter.swift` |
| F1 | `Features/Globe/**` |
| F2 | `Features/Capture/**` |
| F3 | `Features/Collection/**` |
| F4 | `Features/Stats/**` |
| F5 | `Features/Passport/**` (incl. SampleData.swift), `Features/Paywall/**` |
| F6 | `Features/Onboarding/**` |
| F7 | `PlatesWidgets/**` (own target — no app imports) |

## v1.1 additions

- **Profile identity** — `Features/Passport/ProfileStore.swift` (`@Observable`, singleton):
  display name + profile photo (ImageStore-backed, UserDefaults keys `profileName` /
  `profilePhotoPath`). Passport hero shows the photo in the gold ring; tap to change.
- **Passport sharing** — `Features/Passport/PassportShareCard.swift`, a 1080×1350
  share graphic (photo/monogram, name, stat trio, top badges, top cuisines), shared
  from PassportView alongside the year card.
- **Discover tab** (`AppTab.discover`, sparkles icon) — `Features/Discover/**` +
  `Core/Services/TasteEngine.swift`. TasteProfile is computed from the collection
  (top cuisines, Michelin/Bib affinity, avg spend, favorite dishes). Recommendations
  for a searched city (or "Near me") merge Michelin-catalog candidates within 40 km
  with Apple Maps searches for the user's top cuisines, scored by taste match;
  per-recommendation one-line reasons come from FoundationModels when available
  (single batched prompt, 6 s timeout) with deterministic template fallback.
  Needs ≥3 plates before it activates.
