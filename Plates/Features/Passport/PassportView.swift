import SwiftUI
import SwiftData

/// The collector's identity page: lifetime stats, streaks, the badge cabinet,
/// a shareable year card, the Pro upsell, and settings.
struct PassportView: View {
    @Query(sort: \Restaurant.addedAt, order: .reverse) private var restaurants: [Restaurant]
    @Environment(StoreService.self) private var store

    @State private var showPaywall = false
    @State private var shareImage: Image?

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    var body: some View {
        let stats = StatsEngine.lifetime(restaurants: restaurants)

        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroCard(stats)
                    streakCard(stats)
                    badgeSection
                    shareSection
                    proSection
                    SettingsSection(restaurants: restaurants)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .background(Color.plBackground.ignoresSafeArea())
            .navigationTitle("Passport")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .task(id: shareRenderKey) {
                renderShareCard()
            }
        }
    }

    // MARK: - Hero

    private func heroCard(_ stats: LifetimeStats) -> some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .strokeBorder(LinearGradient.plGold, lineWidth: 2)
                    .frame(width: 88, height: 88)
                Circle()
                    .strokeBorder(Color.plGold.opacity(0.35), lineWidth: 1)
                    .frame(width: 70, height: 70)
                Text("P")
                    .font(.plDisplay(36))
                    .foregroundStyle(LinearGradient.plGold)
            }
            .plGlow(.plGold, radius: 10)

            VStack(spacing: 5) {
                Text("Your Passport")
                    .font(.plDisplay(28))
                    .foregroundStyle(Color.plText)
                if stats.plateCount == 0 {
                    Text("Scan a receipt to collect your first plate.")
                        .font(.subheadline)
                        .foregroundStyle(Color.plTextSecondary)
                }
            }

            HStack(spacing: 0) {
                statColumn(value: Text(verbatim: "\(stats.plateCount)"),
                           label: "Plates")
                statDivider
                statColumn(value: starValue(stats.michelinStarsCollected),
                           label: "Stars")
                statDivider
                statColumn(value: Text(verbatim: "\(stats.countryCount)"),
                           label: "Countries")
            }
        }
        .frame(maxWidth: .infinity)
        .plCard(padding: 24)
    }

    private func starValue(_ count: Int) -> Text {
        Text("★ ").foregroundStyle(Color.plGold) + Text(verbatim: "\(count)")
    }

    private func statColumn(value: Text, label: String) -> some View {
        VStack(spacing: 3) {
            value
                .font(.plNumber(28))
                .foregroundStyle(Color.plText)
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1)
                .foregroundStyle(Color.plTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.plStroke)
            .frame(width: 1, height: 34)
    }

    // MARK: - Streak

    private func streakCard(_ stats: LifetimeStats) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.plSurfaceElevated)
                    .frame(width: 46, height: 46)
                Image(systemName: "flame.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(stats.currentMonthlyStreak > 0
                                     ? AnyShapeStyle(LinearGradient.plGold)
                                     : AnyShapeStyle(Color.plTextSecondary))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(streakTitle(stats.currentMonthlyStreak))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.plText)
                Text("Best \(stats.bestMonthlyStreak)")
                    .font(.caption)
                    .foregroundStyle(Color.plTextSecondary)
            }

            Spacer(minLength: 12)

            monthDotStrip
        }
        .plCard()
    }

    private func streakTitle(_ streak: Int) -> String {
        streak == 0 ? "No streak yet" : "\(streak)-month streak"
    }

    /// The last 12 months, oldest first — lit when that month gained a plate.
    private var monthDots: [Bool] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        guard let year = components.year, let month = components.month else {
            return Array(repeating: false, count: 12)
        }
        let nowIndex = year * 12 + (month - 1)

        var plateMonths = Set<Int>()
        for restaurant in restaurants {
            let added = calendar.dateComponents([.year, .month],
                                                from: restaurant.addedAt)
            if let addedYear = added.year, let addedMonth = added.month {
                plateMonths.insert(addedYear * 12 + (addedMonth - 1))
            }
        }
        return (0..<12).map { offset in
            plateMonths.contains(nowIndex - 11 + offset)
        }
    }

    private var monthDotStrip: some View {
        HStack(spacing: 4) {
            ForEach(Array(monthDots.enumerated()), id: \.offset) { _, lit in
                Circle()
                    .fill(lit
                          ? AnyShapeStyle(LinearGradient.plGold)
                          : AnyShapeStyle(Color.plStroke))
                    .frame(width: 6, height: 6)
                    .shadow(color: lit ? Color.plGold.opacity(0.6) : .clear,
                            radius: 2)
            }
        }
        .accessibilityLabel("Last twelve months of collecting")
    }

    // MARK: - Badges

    private var badgeSection: some View {
        let badges = BadgeEngine.badges(restaurants: restaurants)
        let earnedCount = badges.filter(\.earned).count

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("BADGES")
                    .font(.footnote.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(Color.plTextSecondary)
                Spacer()
                Text("\(earnedCount) of \(badges.count)")
                    .font(.plNumber(13, weight: .semibold))
                    .foregroundStyle(Color.plTextSecondary)
            }
            .padding(.horizontal, 4)

            BadgeGrid(badges: badges)
        }
    }

    // MARK: - Share your year

    private var shareSection: some View {
        Group {
            if let shareImage {
                ShareLink(item: shareImage,
                          preview: SharePreview("My \(String(currentYear)) in Plates",
                                                image: shareImage)) {
                    shareLabel
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
            } else {
                shareLabel
                    .opacity(0.5)
            }
        }
    }

    private var shareLabel: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.plSurfaceElevated)
                    .frame(width: 46, height: 46)
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.plGold)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Share your year")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.plText)
                Text("A snapshot of your \(String(currentYear)) in food")
                    .font(.caption)
                    .foregroundStyle(Color.plTextSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.plTextSecondary)
        }
        .plCard()
    }

    private var shareRenderKey: String {
        let visitCount = restaurants.reduce(0) { $0 + $1.visits.count }
        return "\(restaurants.count)|\(visitCount)|\(CurrencyConverter.homeCurrency)"
    }

    @MainActor
    private func renderShareCard() {
        let renderer = ImageRenderer(content: makeYearShareCard())
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1350)
        renderer.scale = 1
        renderer.isOpaque = true
        if let uiImage = renderer.uiImage {
            shareImage = Image(uiImage: uiImage)
        }
    }

    private func makeYearShareCard() -> YearShareCard {
        let calendar = Calendar.current
        let year = currentYear
        let yearStats = StatsEngine.yearStats(year: year, restaurants: restaurants)

        var activeMonths = [Bool](repeating: false, count: 12)
        var stars = 0
        for restaurant in restaurants
        where calendar.component(.year, from: restaurant.addedAt) == year {
            stars += max(0, restaurant.michelinStars)
            let month = calendar.component(.month, from: restaurant.addedAt)
            if (1...12).contains(month) {
                activeMonths[month - 1] = true
            }
        }

        var topCuisines = yearStats.cuisineSpend.prefix(3).map(\.cuisine)
        if topCuisines.isEmpty {
            topCuisines = StatsEngine.lifetime(restaurants: restaurants)
                .cuisineCounts.prefix(3).map(\.cuisine)
        }

        return YearShareCard(year: year,
                             totalSpentHome: yearStats.totalSpendHome,
                             currencyCode: CurrencyConverter.homeCurrency,
                             platesAdded: yearStats.newRestaurants,
                             starsCollected: stars,
                             topCuisines: topCuisines,
                             activeMonths: activeMonths)
    }

    // MARK: - Pro

    private var proSection: some View {
        Group {
            if store.isPro {
                HStack(spacing: 10) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(LinearGradient.plGold)
                    Text("Pro · thank you")
                        .font(.subheadline)
                        .foregroundStyle(Color.plTextSecondary)
                    Spacer()
                }
                .plCard()
            } else {
                Button {
                    Haptics.tap()
                    showPaywall = true
                } label: {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Plates Pro")
                                .font(.plDisplay(22))
                                .foregroundStyle(Color(hex: 0x14100A))
                            Text("Collect without limits")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color(hex: 0x14100A).opacity(0.75))
                        }
                        Spacer()
                        Image(systemName: "crown.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(Color(hex: 0x14100A).opacity(0.85))
                    }
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient.plGold))
                    .plGlow(.plGold, radius: 10)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
