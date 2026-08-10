import SwiftUI

/// The payoff: gold plate bloom, serif name, Michelin star-burst when it applies,
/// and freshly earned badges sliding in. Auto-advances, or "Done" dismisses.
struct CelebrationView: View {
    var model: CaptureModel
    var onDone: () -> Void

    @State private var bloom = false
    @State private var plateShown = false
    @State private var textShown = false
    @State private var starsShown = false
    @State private var badgesShown = false

    private var restaurant: Restaurant? { model.savedRestaurant }
    private var stars: Int { restaurant?.michelinStars ?? 0 }
    private var isMichelin: Bool { stars > 0 }

    var body: some View {
        ZStack {
            Color.plBackground.ignoresSafeArea()
            RadialGradient(colors: [Color.plGoldDeep.opacity(isMichelin ? 0.10 : 0.16),
                                    Color.plBackground.opacity(0)],
                           center: .center, startRadius: 10, endRadius: 340)
                .ignoresSafeArea()
            if isMichelin {
                RadialGradient(colors: [Color.plMichelin.opacity(0.12),
                                        Color.plBackground.opacity(0)],
                               center: .center, startRadius: 10, endRadius: 380)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                Spacer()

                plateBloom
                    .frame(height: 240)

                VStack(spacing: 12) {
                    Text(restaurant?.name ?? "")
                        .font(.plDisplay(32))
                        .foregroundStyle(Color.plText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    if isMichelin {
                        starBurst
                    }

                    Text(subtitle)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .kerning(2.4)
                        .textCase(.uppercase)
                        .foregroundStyle(isMichelin ? Color.plMichelin : Color.plGold)
                }
                .opacity(textShown ? 1 : 0)
                .offset(y: textShown ? 0 : 16)

                Spacer()

                if !model.earnedBadges.isEmpty {
                    badgeStack
                        .padding(.bottom, 18)
                }

                Button {
                    Haptics.tap()
                    onDone()
                } label: {
                    Text("Done")
                }
                .buttonStyle(PlPrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .opacity(textShown ? 1 : 0)
            }
        }
        .task { await runSequence() }
    }

    private var subtitle: String {
        if isMichelin, model.savedIsNew {
            return "★×\(stars) collected"
        }
        if model.savedIsNew {
            return "Plate collected"
        }
        return "Visit #\(restaurant?.visitCount ?? 1) logged"
    }

    // MARK: - Plate bloom

    private var plateBloom: some View {
        ZStack {
            // Concentric rings blooming outward, forever, softly.
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(Color.plGold.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 150, height: 150)
                    .scaleEffect(bloom ? 2.3 : 0.6)
                    .opacity(bloom ? 0 : 0.7)
                    .animation(
                        .easeOut(duration: 2.6)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.85),
                        value: bloom
                    )
            }

            // The plate itself: gold rim, inner well, tonight's cuisine at the center.
            ZStack {
                Circle()
                    .fill(Color.plSurface)
                    .frame(width: 150, height: 150)
                Circle()
                    .strokeBorder(LinearGradient.plGold, lineWidth: 5)
                    .frame(width: 150, height: 150)
                Circle()
                    .strokeBorder(Color.plGoldDeep.opacity(0.55), lineWidth: 1.5)
                    .frame(width: 104, height: 104)
                Text(restaurant?.cuisine.emoji ?? Cuisine.other.emoji)
                    .font(.system(size: 44))
            }
            .plGlow(.plGold, radius: plateShown ? 26 : 4)
            .scaleEffect(plateShown ? 1 : 0.3)
            .opacity(plateShown ? 1 : 0)
        }
    }

    // MARK: - Michelin star-burst

    private var starBurst: some View {
        HStack(spacing: 10) {
            ForEach(0..<stars, id: \.self) { index in
                Image(systemName: "star.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(
                        LinearGradient(colors: [Color.plMichelin, Color.plGoldDeep],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .plGlow(.plMichelin, radius: 10)
                    .scaleEffect(starsShown ? 1 : 0.01)
                    .rotationEffect(.degrees(starsShown ? 0 : -120))
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.55)
                        .delay(0.15 * Double(index)),
                        value: starsShown
                    )
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Badges

    private var badgeStack: some View {
        VStack(spacing: 8) {
            ForEach(Array(model.earnedBadges.prefix(3).enumerated()), id: \.element.id) { index, badge in
                HStack(spacing: 12) {
                    Image(systemName: badge.symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(badge.tier == .michelin ? Color.plMichelin : Color.plGold)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.plSurfaceElevated))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(badge.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.plText)
                        Text(badge.blurb)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.plTextSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text("Unlocked")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.plBackground)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(LinearGradient.plGold))
                }
                .plCard(padding: 12)
                .opacity(badgesShown ? 1 : 0)
                .offset(y: badgesShown ? 0 : 36)
                .animation(
                    .spring(response: 0.55, dampingFraction: 0.8)
                    .delay(0.12 * Double(index)),
                    value: badgesShown
                )
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Choreography

    private func runSequence() async {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) {
            plateShown = true
        }
        bloom = true

        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(.easeOut(duration: 0.5)) {
            textShown = true
        }
        starsShown = true

        try? await Task.sleep(for: .milliseconds(650))
        badgesShown = true

        // Auto-advance once the moment has landed; Done skips ahead any time.
        try? await Task.sleep(for: .seconds(model.earnedBadges.isEmpty ? 4.5 : 6))
        onDone()
    }
}
