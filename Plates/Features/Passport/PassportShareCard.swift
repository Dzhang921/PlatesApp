import SwiftUI

/// A 1080×1350 (4:5) share graphic — the collector's lifetime passport card.
/// Rendered off-screen with `ImageRenderer` at scale 1 (like `YearShareCard`);
/// it is never shown live in the UI, so every dimension below is in final
/// pixels.
struct PassportShareCard: View {
    /// Empty when the collector hasn't set a name.
    var displayName: String
    var photo: UIImage?
    var plateCount: Int
    var starCount: Int
    var countryCount: Int
    /// Up to five earned badges, most impressive first.
    var badges: [Badge]
    /// Up to three cuisines, most collected first.
    var topCuisines: [Cuisine]
    /// Year of the earliest plate (the current year for an empty collection).
    var collectorSince: Int

    var body: some View {
        ZStack {
            Color.plBackground

            RadialGradient(colors: [Color.plGold.opacity(0.15), .clear],
                           center: UnitPoint(x: 0.5, y: 0.08),
                           startRadius: 60,
                           endRadius: 820)

            VStack(spacing: 0) {
                avatar

                Text(displayName.isEmpty ? "My Plates Passport" : displayName)
                    .font(.plDisplay(displayName.isEmpty ? 64 : 76))
                    .foregroundStyle(Color.plText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.top, 36)

                if !displayName.isEmpty {
                    Text("PLATES PASSPORT")
                        .font(.system(size: 26, weight: .semibold))
                        .tracking(10)
                        .foregroundStyle(Color.plTextSecondary)
                        .padding(.top, 10)
                }

                Spacer(minLength: 40)

                statTrio

                Spacer(minLength: 40)

                if !badges.isEmpty {
                    badgeRow
                    Spacer(minLength: 40)
                }

                bottomStrip

                Spacer(minLength: 36)

                wordmark
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 84)
        }
        .frame(width: 1080, height: 1350)
    }

    // MARK: - Avatar

    private var avatar: some View {
        ZStack {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 244, height: 244)
                    .clipShape(Circle())
            } else {
                Text(initial)
                    .font(.plDisplay(110))
                    .foregroundStyle(LinearGradient.plGold)
            }
            Circle()
                .strokeBorder(Color.plGold.opacity(0.4), lineWidth: 2)
                .frame(width: 216, height: 216)
            Circle()
                .strokeBorder(LinearGradient.plGold, lineWidth: 5)
                .frame(width: 268, height: 268)
        }
        .plGlow(.plGold, radius: 26)
    }

    private var initial: String {
        guard let first = displayName
            .trimmingCharacters(in: .whitespaces).first else { return "P" }
        return String(first).uppercased()
    }

    // MARK: - Stats

    private var statTrio: some View {
        HStack(spacing: 0) {
            stat(value: Text(verbatim: "\(plateCount)"), label: "Plates")
            statDivider
            stat(value: starValue, label: "Stars")
            statDivider
            stat(value: Text(verbatim: "\(countryCount)"), label: "Countries")
        }
    }

    private var starValue: Text {
        Text("★ ").foregroundStyle(Color.plGold) + Text(verbatim: "\(starCount)")
    }

    private func stat(value: Text, label: String) -> some View {
        VStack(spacing: 12) {
            value
                .font(.plNumber(88))
                .foregroundStyle(Color.plText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label.uppercased())
                .font(.system(size: 24, weight: .semibold))
                .tracking(4)
                .foregroundStyle(Color.plTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.plStroke)
            .frame(width: 2, height: 96)
    }

    // MARK: - Badges

    private var badgeRow: some View {
        HStack(spacing: 16) {
            ForEach(badges.prefix(5)) { badge in
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.plSurfaceElevated)
                        Circle()
                            .strokeBorder(Color.plGold.opacity(0.55),
                                          lineWidth: 2.5)
                        Image(systemName: badge.symbol)
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(LinearGradient.plGold)
                    }
                    .frame(width: 104, height: 104)

                    Text(badge.name)
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(Color.plTextSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Bottom strip

    private var bottomStrip: some View {
        HStack(spacing: 20) {
            if !topCuisines.isEmpty {
                HStack(spacing: 12) {
                    ForEach(topCuisines.prefix(3)) { cuisine in
                        ZStack {
                            Circle().fill(Color.plSurfaceElevated)
                            Circle().strokeBorder(Color.plStroke, lineWidth: 2)
                            Text(cuisine.emoji)
                                .font(.system(size: 34))
                        }
                        .frame(width: 72, height: 72)
                    }
                }
                Circle()
                    .fill(Color.plStroke)
                    .frame(width: 6, height: 6)
            }
            Text("Collector since \(String(collectorSince))")
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(Color.plTextSecondary)
        }
    }

    // MARK: - Wordmark

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
