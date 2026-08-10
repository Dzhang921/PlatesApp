import SwiftUI
import SwiftData

/// The Stats tab — a year-by-year and lifetime look at the collection:
/// spend hero, monthly bars, cuisine donut, favorite dish, top tables,
/// the Michelin tally and a lifetime strip.
struct StatsView: View {
    @Query(sort: \Restaurant.addedAt) private var restaurants: [Restaurant]
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @Namespace private var chipNamespace

    var body: some View {
        NavigationStack {
            ScrollView {
                if totalVisitCount == 0 {
                    emptyState
                        .padding(.horizontal, 16)
                        .padding(.top, 48)
                } else {
                    content
                }
            }
            .scrollIndicators(.hidden)
            .background(Color.plBackground.ignoresSafeArea())
            .navigationTitle("Stats")
        }
    }

    // MARK: - Data

    private var totalVisitCount: Int {
        restaurants.reduce(0) { $0 + $1.visitCount }
    }

    /// Distinct country codes in the order they were collected (query is addedAt-sorted).
    private var collectedCountryCodes: [String] {
        var codes: [String] = []
        for restaurant in restaurants where !restaurant.countryCode.isEmpty {
            if !codes.contains(restaurant.countryCode) {
                codes.append(restaurant.countryCode)
            }
        }
        return codes
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        let stats = StatsEngine.yearStats(year: selectedYear, restaurants: restaurants)
        let life = StatsEngine.lifetime(restaurants: restaurants)
        let home = CurrencyConverter.homeCurrency

        VStack(spacing: 16) {
            yearSelector

            Group {
                heroCard(stats: stats, home: home)

                StatsMonthlyChart(monthlySpend: stats.monthlySpend,
                                  year: stats.year,
                                  currencyCode: home)

                if !stats.cuisineSpend.isEmpty {
                    StatsCuisineDonut(cuisineSpend: stats.cuisineSpend,
                                      favorite: life.favoriteCuisine,
                                      currencyCode: home)
                }

                if let topDish = life.favoriteDishes.first {
                    StatsFavoriteDishCard(topDish: topDish,
                                          runnersUp: Array(life.favoriteDishes.dropFirst().prefix(4)))
                }

                if !stats.topRestaurants.isEmpty {
                    StatsTopRestaurantsCard(entries: stats.topRestaurants, currencyCode: home)
                }

                if life.michelinStarsCollected > 0 || life.bibGourmandCount > 0 {
                    StatsMichelinCard(lifetime: life)
                }

                StatsLifetimeCard(lifetime: life, countryCodes: collectedCountryCodes)
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 2)
        .padding(.bottom, 28)
    }

    // MARK: - Year selector

    private var yearSelector: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(StatsEngine.availableYears(restaurants: restaurants), id: \.self) { year in
                    yearChip(year)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }

    private func yearChip(_ year: Int) -> some View {
        let isSelected = year == selectedYear
        return Button {
            guard year != selectedYear else { return }
            Haptics.tap()
            withAnimation(.snappy(duration: 0.32)) {
                selectedYear = year
            }
        } label: {
            Text(String(year))
                .font(.plNumber(15, weight: .semibold))
                .foregroundStyle(isSelected ? Color(hex: 0x14100A) : Color.plTextSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(LinearGradient.plGold)
                            .matchedGeometryEffect(id: "pl-year-chip", in: chipNamespace)
                    } else {
                        Capsule()
                            .fill(Color.plSurface)
                            .overlay(Capsule().strokeBorder(Color.plStroke, lineWidth: 1))
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero

    private func heroCard(stats: YearStats, home: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            StatsSectionLabel("Spent on food")

            Text(plMoney(stats.totalSpendHome, home))
                .font(.plNumber(46))
                .foregroundStyle(LinearGradient.plGold)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText(value: stats.totalSpendHome.plDouble))

            Text(heroSubline(stats: stats, home: home))
                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                .foregroundStyle(Color.plTextSecondary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .plCard(padding: 18)
    }

    private func heroSubline(stats: YearStats, home: String) -> String {
        let visits = stats.visitCount == 1 ? "1 visit" : "\(stats.visitCount) visits"
        let places = stats.restaurantsVisited == 1 ? "1 restaurant" : "\(stats.restaurantsVisited) restaurants"
        return "\(visits) · \(places) · avg \(plMoney(stats.averagePerVisit, home))"
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.plSurfaceElevated)
                    .frame(width: 76, height: 76)
                Image(systemName: "receipt")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(LinearGradient.plGold)
            }
            .padding(.bottom, 4)

            Text("Your stats begin with your first receipt.")
                .font(.plDisplay(21))
                .foregroundStyle(Color.plText)
                .multilineTextAlignment(.center)

            Text("Scan one and watch the numbers roll in.")
                .font(.system(size: 14))
                .foregroundStyle(Color.plTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .plCard(padding: 20)
    }
}

// MARK: - Shared section label

/// Small tracked-uppercase label used at the top of every stats card.
struct StatsSectionLabel: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.5)
            .foregroundStyle(Color.plTextSecondary)
    }
}
