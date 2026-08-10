import SwiftUI

// MARK: - Section label

/// Small tracked-uppercase label used at the top of Discover sections and cards.
struct DiscoverSectionLabel: View {
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

// MARK: - Taste card

/// "Your taste" — the top-3 cuisines big and proud, the star affinity row,
/// the average spend and the favorite dish.
struct DiscoverTasteCard: View {
    let profile: TasteProfile
    let starsCollected: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DiscoverSectionLabel("Your taste")

            HStack(spacing: 0) {
                let top = Array(profile.topCuisines.prefix(3))
                ForEach(Array(top.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 {
                        columnDivider
                    }
                    cuisineColumn(entry)
                }
            }

            Divider()
                .overlay(Color.plStroke.opacity(0.7))

            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(starsCollected > 0
                                     ? Color.plMichelin
                                     : Color.plTextSecondary.opacity(0.5))
                Text(starLine)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Color.plText)
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                averageChip
                if let dish = profile.favoriteDishes.first {
                    dishChip(dish)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .plCard(padding: 18)
    }

    private var starLine: String {
        guard starsCollected > 0 else { return "Not yet starred" }
        return starsCollected == 1
            ? "1 Michelin star collected"
            : "\(starsCollected) Michelin stars collected"
    }

    private var columnDivider: some View {
        Rectangle()
            .fill(Color.plStroke.opacity(0.7))
            .frame(width: 1, height: 44)
    }

    private func cuisineColumn(_ entry: CuisineCount) -> some View {
        VStack(spacing: 4) {
            Text(entry.cuisine.emoji)
                .font(.system(size: 34))
            Text(entry.cuisine.displayName)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color.plText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("×\(entry.count)")
                .font(.plNumber(11, weight: .semibold))
                .foregroundStyle(Color.plTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var averageChip: some View {
        HStack(spacing: 5) {
            Text("avg")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.plTextSecondary)
            Text(plMoney(profile.avgPerVisitHome, CurrencyConverter.homeCurrency))
                .font(.plNumber(13, weight: .semibold))
                .foregroundStyle(Color.plGold)
            Text("per visit")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.plTextSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.plSurfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.plStroke, lineWidth: 1))
    }

    private func dishChip(_ dish: DishCount) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "heart.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color.plGold)
            Text(dish.name.capitalized)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.plText)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.plSurfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.plStroke, lineWidth: 1))
    }
}

// MARK: - Teaser (fewer than 3 plates)

/// Graceful gate shown until the profile has enough plates to read.
struct DiscoverTeaserCard: View {
    let plateCount: Int
    let needed: Int

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.plSurfaceElevated)
                    .frame(width: 76, height: 76)
                Image(systemName: "sparkles")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(LinearGradient.plGold)
            }
            .padding(.bottom, 4)

            Text("Discover unlocks at \(needed) plates.")
                .font(.plDisplay(21))
                .foregroundStyle(Color.plText)
                .multilineTextAlignment(.center)

            Text("Collect a few more plates so Plates can learn your taste.")
                .font(.system(size: 14))
                .foregroundStyle(Color.plTextSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                ForEach(0..<needed, id: \.self) { index in
                    Circle()
                        .fill(index < plateCount
                              ? AnyShapeStyle(LinearGradient.plGold)
                              : AnyShapeStyle(Color.plSurfaceElevated))
                        .overlay(
                            Circle().strokeBorder(Color.plStroke,
                                                  lineWidth: index < plateCount ? 0 : 1)
                        )
                        .frame(width: 10, height: 10)
                }
                Text("\(plateCount) of \(needed)")
                    .font(.plNumber(12, weight: .semibold))
                    .foregroundStyle(Color.plTextSecondary)
                    .padding(.leading, 4)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .plCard(padding: 20)
    }
}

// MARK: - Loading

/// Gold shimmer while the taste engine reads the Guide and Apple Maps.
struct DiscoverLoadingCard: View {
    @State private var phase: CGFloat = -0.7

    var body: some View {
        VStack(spacing: 10) {
            shimmerText("Reading your taste…")
            Text("Matching the Michelin Guide and Apple Maps to your history")
                .font(.system(size: 12.5))
                .foregroundStyle(Color.plTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .plCard(padding: 20)
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 1.4
            }
        }
    }

    private func shimmerText(_ text: String) -> some View {
        Text(text)
            .font(.plDisplay(19))
            .foregroundStyle(Color.plTextSecondary.opacity(0.6))
            .overlay {
                Text(text)
                    .font(.plDisplay(19))
                    .foregroundStyle(LinearGradient.plGold)
                    .mask {
                        GeometryReader { geo in
                            LinearGradient(colors: [.clear, .white, .clear],
                                           startPoint: .leading,
                                           endPoint: .trailing)
                                .frame(width: geo.size.width * 0.7)
                                .offset(x: phase * geo.size.width)
                        }
                    }
            }
    }
}

// MARK: - Recommendation card

/// One ranked pick: name, cuisine and Michelin chips, the personalized reason,
/// and the address. Tapping hands off to Apple Maps; collected places fade.
struct DiscoverRecommendationCard: View {
    let rank: Int
    let recommendation: Recommendation
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(rank)")
                    .font(.plNumber(15, weight: .semibold))
                    .foregroundStyle(rank == 1
                                     ? AnyShapeStyle(LinearGradient.plGold)
                                     : AnyShapeStyle(Color.plTextSecondary))
                    .frame(width: 22, alignment: .center)
                    .padding(.top, 3)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(recommendation.name)
                            .font(.plDisplay(18))
                            .foregroundStyle(Color.plText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                        if recommendation.alreadyCollected {
                            collectedChip
                        }
                    }

                    HStack(spacing: 6) {
                        cuisineChip
                        if recommendation.stars > 0 {
                            starChip
                        } else if recommendation.isBibGourmand {
                            bibChip
                        }
                    }

                    Text(recommendation.reason)
                        .font(.system(size: 13))
                        .italic()
                        .foregroundStyle(Color.plTextSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if !recommendation.address.isEmpty {
                        Text(recommendation.address)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.plTextSecondary.opacity(0.75))
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .plCard(padding: 16)
        .opacity(recommendation.alreadyCollected ? 0.55 : 1)
    }

    private var cuisineChip: some View {
        HStack(spacing: 4) {
            Text(recommendation.cuisineEmoji)
                .font(.system(size: 11))
            Text(recommendation.cuisineText)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color.plText)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.plSurfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.plStroke, lineWidth: 1))
    }

    private var starChip: some View {
        Text("★×\(recommendation.stars)")
            .font(.plNumber(11.5, weight: .semibold))
            .foregroundStyle(Color.plMichelin)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.plMichelin.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.plMichelin.opacity(0.38), lineWidth: 1))
    }

    private var bibChip: some View {
        Text("Bib")
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(Color.plMichelin)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.plMichelin.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.plMichelin.opacity(0.38), lineWidth: 1))
    }

    private var collectedChip: some View {
        Text("Collected ✓")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.plGold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.plGold.opacity(0.12)))
            .overlay(Capsule().strokeBorder(Color.plGold.opacity(0.35), lineWidth: 1))
    }
}

// MARK: - Empty results

/// Shown when a chosen city produced no candidates at all.
struct DiscoverEmptyResultsCard: View {
    let cityName: String

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.plSurfaceElevated)
                    .frame(width: 64, height: 64)
                Image(systemName: "binoculars")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(LinearGradient.plGold)
            }
            .padding(.bottom, 2)

            Text("Nothing matched your taste here yet — collect it first!")
                .font(.plDisplay(18))
                .foregroundStyle(Color.plText)
                .multilineTextAlignment(.center)

            Text("Try a plain \"restaurants in \(cityName)\" search in Maps, eat somewhere great, and scan the receipt.")
                .font(.system(size: 13))
                .foregroundStyle(Color.plTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .plCard(padding: 20)
    }
}
