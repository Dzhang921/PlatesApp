import SwiftUI

/// The shareable plate graphic: a 540×675 pt dark card rendered offscreen with
/// `ImageRenderer` at scale 2 → a 1080×1350 px image (Instagram portrait).
/// Gold plate-ring motif, serif name, city, cuisine, Michelin stars, collected line,
/// and a small Plates wordmark.
struct RestaurantShareCard: View {
    let restaurant: Restaurant

    private var collectedLine: String {
        let date = restaurant.addedAt.formatted(date: .abbreviated, time: .omitted)
        let visits = restaurant.visitCount
        return "Collected \(date) · \(visits) visit\(visits == 1 ? "" : "s")"
    }

    private var cityLine: String {
        switch (restaurant.city.isEmpty, restaurant.country.isEmpty) {
        case (false, false): return "\(restaurant.city) · \(restaurant.country)"
        case (false, true): return restaurant.city
        case (true, false): return restaurant.country
        case (true, true): return ""
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            plateRing
                .padding(.top, 64)

            Text(restaurant.name)
                .font(.plDisplay(40))
                .foregroundStyle(Color.plText)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.55)
                .padding(.horizontal, 44)
                .padding(.top, 34)

            if !cityLine.isEmpty {
                Text(cityLine)
                    .font(.system(size: 17))
                    .foregroundStyle(Color.plTextSecondary)
                    .lineLimit(1)
                    .padding(.top, 10)
                    .padding(.horizontal, 40)
            }

            HStack(spacing: 8) {
                Text(restaurant.cuisine.emoji)
                    .font(.system(size: 14))
                Text(restaurant.cuisine.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.plTextSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.plSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.plStroke, lineWidth: 1)
            )
            .padding(.top, 16)

            if restaurant.isMichelin {
                VStack(spacing: 6) {
                    HStack(spacing: 5) {
                        ForEach(0..<restaurant.michelinStars, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.plMichelin)
                        }
                    }
                    Text("MICHELIN GUIDE")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(3)
                        .foregroundStyle(Color.plMichelin.opacity(0.85))
                }
                .padding(.top, 18)
            } else if restaurant.isBibGourmand {
                Text("BIB GOURMAND")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(Color.plMichelin.opacity(0.85))
                    .padding(.top, 18)
            }

            Rectangle()
                .fill(Color.plStroke)
                .frame(width: 200, height: 1)
                .padding(.top, 24)

            Text(collectedLine)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.plTextSecondary)
                .padding(.top, 16)

            Spacer(minLength: 12)

            wordmark
                .padding(.bottom, 40)
        }
        .frame(width: 540, height: 675)
        .background(cardBackground)
    }

    private var plateRing: some View {
        ZStack {
            Circle()
                .strokeBorder(LinearGradient.plGold, lineWidth: 2)
                .frame(width: 196, height: 196)
            Circle()
                .strokeBorder(Color.plGold.opacity(0.25), lineWidth: 1)
                .frame(width: 172, height: 172)
            Circle()
                .fill(Color.plSurfaceElevated)
                .frame(width: 148, height: 148)
            Circle()
                .strokeBorder(Color.plStroke, lineWidth: 1)
                .frame(width: 148, height: 148)
            Text(restaurant.cuisine.emoji)
                .font(.system(size: 64))
        }
        .shadow(color: Color.plGold.opacity(0.28), radius: 30)
    }

    private var wordmark: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.plGold.opacity(0.4))
                .frame(width: 36, height: 1)
            Text("PLATES")
                .font(.plDisplay(15))
                .tracking(7)
                .foregroundStyle(LinearGradient.plGold)
            Rectangle()
                .fill(Color.plGold.opacity(0.4))
                .frame(width: 36, height: 1)
        }
    }

    private var cardBackground: some View {
        ZStack {
            Color.plBackground
            RadialGradient(colors: [Color.plGold.opacity(0.10), .clear],
                           center: UnitPoint(x: 0.5, y: 0.22),
                           startRadius: 20,
                           endRadius: 400)
        }
    }
}
