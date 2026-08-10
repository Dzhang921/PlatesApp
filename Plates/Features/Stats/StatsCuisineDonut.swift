import SwiftUI
import Charts

/// Donut of the year's spend by cuisine — top six plus "Other" — with the
/// favorite cuisine sitting in the hole and a legend of amounts underneath.
struct StatsCuisineDonut: View {
    let cuisineSpend: [CuisineAmount]
    let favorite: Cuisine?
    let currencyCode: String

    private struct Slice: Identifiable {
        let id: String
        let name: String
        let emoji: String?
        let amount: Decimal
        let style: AnyShapeStyle
    }

    /// Gold-forward palette: the precious metal first, then a few muted
    /// complements so neighboring slices stay distinct.
    private static let palette: [AnyShapeStyle] = [
        AnyShapeStyle(LinearGradient.plGold),
        AnyShapeStyle(Color.plGoldDeep),
        AnyShapeStyle(Color(hex: 0x2E6E6A)),   // deep teal
        AnyShapeStyle(Color.plGold.opacity(0.45)),
        AnyShapeStyle(Color(hex: 0x6E2E5A)),   // plum
        AnyShapeStyle(Color(hex: 0x44506E)),   // slate
    ]

    private var slices: [Slice] {
        let ranked = cuisineSpend.filter { $0.amount > 0 }
        var result: [Slice] = []
        for (index, entry) in ranked.prefix(6).enumerated() {
            result.append(Slice(id: entry.cuisine.rawValue,
                                name: entry.cuisine.displayName,
                                emoji: entry.cuisine.emoji,
                                amount: entry.amount,
                                style: Self.palette[index]))
        }
        let remainder = ranked.dropFirst(6)
        if !remainder.isEmpty {
            let sum = remainder.reduce(Decimal(0)) { $0 + $1.amount }
            result.append(Slice(id: "pl-other-aggregate",
                                name: "Other",
                                emoji: nil,
                                amount: sum,
                                style: AnyShapeStyle(Color(hex: 0x3C3C4A))))
        }
        return result
    }

    private var total: Decimal {
        slices.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var centerCuisine: Cuisine? {
        favorite ?? cuisineSpend.first?.cuisine
    }

    var body: some View {
        let slices = self.slices
        let total = self.total

        VStack(alignment: .leading, spacing: 14) {
            StatsSectionLabel("By cuisine")

            ZStack {
                Chart(slices) { slice in
                    SectorMark(angle: .value("Spent", slice.amount.plDouble),
                               innerRadius: .ratio(0.62),
                               angularInset: 1.6)
                        .cornerRadius(3)
                        .foregroundStyle(slice.style)
                }
                .frame(height: 216)

                if let cuisine = centerCuisine {
                    VStack(spacing: 3) {
                        Text(cuisine.emoji)
                            .font(.system(size: 34))
                        Text(cuisine.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.plTextSecondary)
                    }
                }
            }
            .padding(.vertical, 2)

            VStack(spacing: 10) {
                ForEach(slices) { slice in
                    legendRow(slice, total: total)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .plCard(padding: 18)
    }

    private func legendRow(_ slice: Slice, total: Decimal) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(slice.style)
                .frame(width: 10, height: 10)

            Text(slice.emoji.map { "\($0) \(slice.name)" } ?? slice.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.plText)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(plMoney(slice.amount, currencyCode))
                .font(.plNumber(13, weight: .semibold))
                .foregroundStyle(Color.plText)
                .contentTransition(.numericText())

            Text(percentText(slice, total: total))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.plTextSecondary)
                .frame(width: 40, alignment: .trailing)
                .contentTransition(.numericText())
        }
    }

    private func percentText(_ slice: Slice, total: Decimal) -> String {
        guard total > 0 else { return "0%" }
        let percent = Int((slice.amount.plDouble / total.plDouble * 100).rounded())
        return "\(percent)%"
    }
}
