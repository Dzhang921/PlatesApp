import SwiftUI

/// A 1080×1350 (4:5) share graphic summarizing a year of collecting.
/// Rendered off-screen with `ImageRenderer` at scale 1 — it is never shown
/// live in the UI, so every dimension below is in final pixels.
struct YearShareCard: View {
    var year: Int
    var totalSpentHome: Decimal
    var currencyCode: String
    var platesAdded: Int
    var starsCollected: Int
    /// Up to three cuisines, most-loved first.
    var topCuisines: [Cuisine]
    /// 12 entries, January first — months that gained a new plate.
    var activeMonths: [Bool]

    var body: some View {
        ZStack {
            Color.plBackground

            RadialGradient(colors: [Color.plGold.opacity(0.16), .clear],
                           center: UnitPoint(x: 0.5, y: 0.06),
                           startRadius: 40,
                           endRadius: 780)

            VStack(spacing: 0) {
                Text(String(year))
                    .font(.plDisplay(148, weight: .bold))
                    .foregroundStyle(LinearGradient.plGold)

                Text("A YEAR OF COLLECTING")
                    .font(.system(size: 29, weight: .semibold))
                    .tracking(11)
                    .foregroundStyle(Color.plTextSecondary)
                    .padding(.top, 4)

                Spacer(minLength: 30)

                Text(plMoney(totalSpentHome, currencyCode))
                    .font(.plNumber(126))
                    .foregroundStyle(Color.plText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text("spent on unforgettable meals")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(Color.plTextSecondary)
                    .padding(.top, 8)

                HStack(spacing: 70) {
                    stat(value: "\(platesAdded)", label: "New plates")
                    stat(value: "★ \(starsCollected)", label: "Michelin stars", gold: true)
                }
                .padding(.top, 58)

                if !topCuisines.isEmpty {
                    cuisineTrio
                        .padding(.top, 58)
                }

                monthStrip
                    .padding(.top, 56)

                Spacer(minLength: 30)

                wordmark
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 84)
        }
        .frame(width: 1080, height: 1350)
    }

    // MARK: - Pieces

    private func stat(value: String, label: String, gold: Bool = false) -> some View {
        VStack(spacing: 10) {
            Text(value)
                .font(.plNumber(62))
                .foregroundStyle(gold
                                 ? AnyShapeStyle(LinearGradient.plGold)
                                 : AnyShapeStyle(Color.plText))
            Text(label.uppercased())
                .font(.system(size: 23, weight: .semibold))
                .tracking(4)
                .foregroundStyle(Color.plTextSecondary)
        }
    }

    private var cuisineTrio: some View {
        HStack(spacing: 30) {
            ForEach(topCuisines.prefix(3)) { cuisine in
                ZStack {
                    Circle().fill(Color.plSurfaceElevated)
                    Circle().strokeBorder(Color.plStroke, lineWidth: 2)
                    Text(cuisine.emoji)
                        .font(.system(size: 62))
                }
                .frame(width: 128, height: 128)
            }
        }
    }

    private var monthStrip: some View {
        HStack(spacing: 22) {
            ForEach(0..<12, id: \.self) { index in
                Circle()
                    .fill(isActive(index)
                          ? AnyShapeStyle(LinearGradient.plGold)
                          : AnyShapeStyle(Color.plStroke))
                    .frame(width: 20, height: 20)
            }
        }
    }

    private func isActive(_ index: Int) -> Bool {
        activeMonths.indices.contains(index) && activeMonths[index]
    }

    private var wordmark: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .strokeBorder(LinearGradient.plGold, lineWidth: 3)
                    .frame(width: 52, height: 52)
                Circle()
                    .strokeBorder(Color.plGold.opacity(0.4), lineWidth: 1.5)
                    .frame(width: 36, height: 36)
            }
            Text("Plates")
                .font(.plDisplay(50))
                .foregroundStyle(Color.plText)
        }
    }
}
