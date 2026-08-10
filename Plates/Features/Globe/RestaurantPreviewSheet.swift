import SwiftUI

/// Medium-detent preview shown when a globe dot is tapped. Read-only, no
/// navigation — a quick, sleek card of the plate.
struct RestaurantPreviewSheet: View {
    let restaurant: Restaurant

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                if restaurant.isMichelin {
                    michelinRow
                }

                Text(restaurant.name)
                    .font(.plDisplay(30))
                    .foregroundStyle(Color.plText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 8) {
                    cuisineChip
                    if restaurant.isBibGourmand && !restaurant.isMichelin {
                        bibGourmandChip
                    }
                }

                locationLine
            }

            metricsCard

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Header pieces

    private var michelinRow: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(0..<restaurant.michelinStars, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.plMichelin)
                }
            }
            Text("MICHELIN")
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Color.plTextSecondary)
        }
    }

    private var cuisineChip: some View {
        HStack(spacing: 6) {
            Text(restaurant.cuisine.emoji)
                .font(.system(size: 13))
            Text(restaurant.cuisine.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.plText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.plSurfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.plStroke, lineWidth: 1))
    }

    private var bibGourmandChip: some View {
        Text("Bib Gourmand")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.plMichelin)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.plSurfaceElevated))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.plStroke, lineWidth: 1))
    }

    private var locationLine: some View {
        HStack(spacing: 5) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.plGold)
            Text(locationText)
                .font(.system(size: 14))
                .foregroundStyle(Color.plTextSecondary)
        }
    }

    private var locationText: String {
        [restaurant.city, restaurant.country]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    // MARK: - Metrics

    private var metricsCard: some View {
        HStack(spacing: 0) {
            metric(value: "\(restaurant.visitCount)",
                   label: restaurant.visitCount == 1 ? "Visit" : "Visits")
            hairline
            metric(value: plMoney(restaurant.totalSpendHome, CurrencyConverter.homeCurrency),
                   label: "Spent")
            hairline
            metric(value: lastVisitText, label: "Last visit")
        }
        .plCard(padding: 16)
    }

    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.plNumber(18))
                .foregroundStyle(Color.plText)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.plTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color.plStroke)
            .frame(width: 1, height: 34)
    }

    private var lastVisitText: String {
        guard let date = restaurant.lastVisitDate else { return "—" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
