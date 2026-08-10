import SwiftUI

/// One collected restaurant in the 2-column collection grid.
/// Emoji up top, serif name, city, then visits × total spent along the bottom.
/// Michelin plates get a thin gold border and a red star chip.
struct PlateCard: View {
    let restaurant: Restaurant

    private var homeCurrency: String { CurrencyConverter.homeCurrency }

    private var cityLine: String {
        restaurant.city.isEmpty ? restaurant.country : restaurant.city
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(restaurant.cuisine.emoji)
                    .font(.system(size: 38))
                Spacer(minLength: 4)
                if restaurant.isMichelin {
                    michelinChip
                } else if restaurant.isBibGourmand {
                    bibChip
                }
            }

            Spacer(minLength: 2)

            Text(restaurant.name)
                .font(.plDisplay(17))
                .foregroundStyle(Color.plText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(minHeight: 42, alignment: .bottomLeading)

            Text(cityLine)
                .font(.system(size: 13))
                .foregroundStyle(Color.plTextSecondary)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline) {
                Text("×\(restaurant.visitCount)")
                    .font(.plNumber(15))
                    .foregroundStyle(Color.plTextSecondary)
                Spacer(minLength: 4)
                Text(plMoney(restaurant.totalSpendHome, homeCurrency))
                    .font(.plNumber(15))
                    .foregroundStyle(Color.plGold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .plCard()
        .overlay {
            if restaurant.isMichelin {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.plGold.opacity(0.55), lineWidth: 1)
            }
        }
    }

    private var michelinChip: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.system(size: 9, weight: .bold))
            Text("×\(restaurant.michelinStars)")
                .font(.plNumber(11))
        }
        .foregroundStyle(Color.plMichelin)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.plMichelin.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.plMichelin.opacity(0.45), lineWidth: 1)
        )
    }

    private var bibChip: some View {
        Text("Bib")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.plMichelin)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.plMichelin.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.plMichelin.opacity(0.35), lineWidth: 1)
            )
    }
}
