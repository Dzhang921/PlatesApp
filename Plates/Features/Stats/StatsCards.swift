import SwiftUI

// MARK: - Favorite dish

/// "Your dish" — the most-ordered dish across every visit, with the
/// runners-up as small chips.
struct StatsFavoriteDishCard: View {
    let topDish: DishCount
    let runnersUp: [DishCount]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatsSectionLabel("Your dish")

            Text(topDish.name.capitalized)
                .font(.plDisplay(24))
                .foregroundStyle(Color.plText)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            Text(orderedText(topDish.count))
                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                .foregroundStyle(Color.plGold)
                .contentTransition(.numericText())

            if !runnersUp.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(runnersUp) { dish in
                            dishChip(dish)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .plCard(padding: 18)
    }

    private func orderedText(_ count: Int) -> String {
        switch count {
        case 1: return "ordered once"
        case 2: return "ordered twice"
        default: return "ordered \(count) times"
        }
    }

    private func dishChip(_ dish: DishCount) -> some View {
        HStack(spacing: 5) {
            Text(dish.name.capitalized)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.plText)
                .lineLimit(1)
            Text("×\(dish.count)")
                .font(.plNumber(12, weight: .semibold))
                .foregroundStyle(Color.plTextSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.plSurfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.plStroke, lineWidth: 1))
    }
}

// MARK: - Top restaurants

/// The year's biggest tables, ranked 1–5 by spend.
struct StatsTopRestaurantsCard: View {
    let entries: [NamedAmount]
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatsSectionLabel("Top restaurants")

            VStack(spacing: 0) {
                ForEach(Array(entries.prefix(5).enumerated()), id: \.element.id) { rank, entry in
                    row(rank: rank, entry: entry)
                    if rank < min(entries.count, 5) - 1 {
                        Divider()
                            .overlay(Color.plStroke.opacity(0.7))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .plCard(padding: 18)
    }

    private func row(rank: Int, entry: NamedAmount) -> some View {
        HStack(spacing: 12) {
            Text("\(rank + 1)")
                .font(.plNumber(14, weight: .semibold))
                .foregroundStyle(rank == 0 ? AnyShapeStyle(LinearGradient.plGold)
                                           : AnyShapeStyle(Color.plTextSecondary))
                .frame(width: 20, alignment: .center)

            Text(entry.name)
                .font(.plDisplay(16, weight: .medium))
                .foregroundStyle(Color.plText)
                .lineLimit(1)

            Spacer(minLength: 10)

            Text(plMoney(entry.amount, currencyCode))
                .font(.plNumber(15, weight: .semibold))
                .foregroundStyle(Color.plText)
                .contentTransition(.numericText())
        }
        .padding(.vertical, 11)
    }
}

// MARK: - Michelin

/// The red card — lifetime stars collected across distinct Michelin
/// restaurants, with the Bib Gourmand tally alongside.
struct StatsMichelinCard: View {
    let lifetime: LifetimeStats

    private var starsOnly: Bool { lifetime.michelinStarsCollected > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MICHELIN")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Color.plMichelin)

            HStack(spacing: 14) {
                Image(systemName: starsOnly ? "star.fill" : "rosette")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.plMichelin)
                    .plGlow(.plMichelin, radius: 8)

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(starsOnly ? lifetime.michelinStarsCollected : lifetime.bibGourmandCount)")
                        .font(.plNumber(40))
                        .foregroundStyle(Color.plText)
                        .contentTransition(.numericText())
                    Text(caption)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.plTextSecondary)
                }
            }

            Text(subline)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.plTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.plSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient(colors: [Color.plMichelin.opacity(0.14), .clear],
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.plMichelin.opacity(0.38), lineWidth: 1)
        )
    }

    private var caption: String {
        if starsOnly {
            return "stars collected"
        }
        return lifetime.bibGourmandCount == 1 ? "Bib Gourmand find" : "Bib Gourmand finds"
    }

    private var subline: String {
        var parts: [String] = []
        if lifetime.michelinPlateCount > 0 {
            parts.append(lifetime.michelinPlateCount == 1
                         ? "1 Michelin restaurant"
                         : "\(lifetime.michelinPlateCount) Michelin restaurants")
        }
        if starsOnly, lifetime.bibGourmandCount > 0 {
            parts.append("\(lifetime.bibGourmandCount) Bib Gourmand")
        }
        if parts.isEmpty {
            return "Michelin's best-value tables"
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Lifetime strip

/// Four lifetime numbers side by side — plates, countries, cities, streak —
/// with the collected flags running along the bottom.
struct StatsLifetimeCard: View {
    let lifetime: LifetimeStats
    let countryCodes: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StatsSectionLabel("Lifetime")

            HStack(spacing: 0) {
                statColumn(value: "\(lifetime.plateCount)", caption: "Plates")
                columnDivider
                statColumn(value: "\(lifetime.countryCount)", caption: "Countries")
                columnDivider
                statColumn(value: "\(lifetime.cityCount)", caption: "Cities")
                columnDivider
                streakColumn
            }

            if !countryCodes.isEmpty {
                Divider()
                    .overlay(Color.plStroke.opacity(0.7))
                Text(countryCodes.compactMap(statsFlagEmoji).joined(separator: " "))
                    .font(.system(size: 15))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .plCard(padding: 18)
    }

    private var columnDivider: some View {
        Rectangle()
            .fill(Color.plStroke.opacity(0.7))
            .frame(width: 1, height: 34)
    }

    private func statColumn(value: String, caption: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.plNumber(22))
                .foregroundStyle(Color.plText)
                .contentTransition(.numericText())
            Text(caption)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Color.plTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var streakColumn: some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(lifetime.currentMonthlyStreak > 0
                                     ? AnyShapeStyle(LinearGradient.plGold)
                                     : AnyShapeStyle(Color.plTextSecondary.opacity(0.5)))
                Text("\(lifetime.currentMonthlyStreak)")
                    .font(.plNumber(22))
                    .foregroundStyle(Color.plText)
                    .contentTransition(.numericText())
            }
            Text("Month streak")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Color.plTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Flags

/// "US" → "🇺🇸" via regional indicator symbols. Nil for anything that is not
/// a two-letter code.
private func statsFlagEmoji(_ countryCode: String) -> String? {
    let code = countryCode.uppercased()
    guard code.count == 2, code.allSatisfy({ $0.isLetter }) else { return nil }
    var flag = ""
    for scalar in code.unicodeScalars {
        guard let regional = UnicodeScalar(127397 + scalar.value) else { return nil }
        flag.unicodeScalars.append(regional)
    }
    return flag
}
