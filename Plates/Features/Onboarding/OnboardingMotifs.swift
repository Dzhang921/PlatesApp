import SwiftUI

// MARK: - Page 1 — the collection globe

/// A large dark-gold globe with a few collected plates glowing on its surface.
/// The dots pop in one by one after the page reveals.
struct OnboardingGlobeMotif: View {
    let revealed: Bool

    private struct Dot {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
    }

    private static let dots: [Dot] = [
        Dot(x: -48, y: -38, size: 9),
        Dot(x: 40, y: -60, size: 8),
        Dot(x: 60, y: 24, size: 10),
        Dot(x: -14, y: 52, size: 8)
    ]

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color.plGold.opacity(0.14), .clear],
                                     center: .center, startRadius: 20, endRadius: 130))
                .frame(width: 260, height: 260)

            Circle()
                .stroke(Color.plGold.opacity(0.12), lineWidth: 1)
                .frame(width: 232, height: 232)

            Image(systemName: "globe.americas.fill")
                .font(.system(size: 196))
                .foregroundStyle(Color.plGold.opacity(0.22))

            ForEach(Self.dots.indices, id: \.self) { index in
                let dot = Self.dots[index]
                Circle()
                    .fill(Color.plGold)
                    .frame(width: dot.size, height: dot.size)
                    .plGlow(radius: 9)
                    .scaleEffect(revealed ? 1 : 0.01)
                    .opacity(revealed ? 1 : 0)
                    .animation(.spring(response: 0.45, dampingFraction: 0.55)
                        .delay(0.55 + Double(index) * 0.15),
                               value: revealed)
                    .offset(x: dot.x, y: dot.y)
            }
        }
    }
}

// MARK: - Page 2 — receipt becomes a plate

/// A receipt card, a drifting gold arrow, and a glowing plate ring: scan the
/// receipt, get the plate.
struct OnboardingReceiptMotif: View {
    let revealed: Bool

    var body: some View {
        HStack(spacing: 18) {
            receipt
                .scaleEffect(revealed ? 1 : 0.92)
                .opacity(revealed ? 1 : 0)
                .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.35),
                           value: revealed)

            arrow
                .opacity(revealed ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.55), value: revealed)

            plateRing
                .scaleEffect(revealed ? 1 : 0.7)
                .opacity(revealed ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.7),
                           value: revealed)
        }
    }

    private var receipt: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.plSurfaceElevated)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.plStroke, lineWidth: 1)
            Image(systemName: "doc.text")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(Color.plText.opacity(0.85))
        }
        .frame(width: 94, height: 122)
    }

    private var arrow: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Color.plGold.opacity(0.85))
            .phaseAnimator([false, true]) { view, phase in
                view
                    .offset(x: phase ? 3 : -3)
                    .opacity(phase ? 1 : 0.5)
            } animation: { _ in
                .easeInOut(duration: 1.0)
            }
    }

    private var plateRing: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color.plGold.opacity(0.12), .clear],
                                     center: .center, startRadius: 8, endRadius: 62))
            Circle()
                .stroke(LinearGradient.plGold, lineWidth: 3.5)
                .padding(6)
            Circle()
                .stroke(Color.plGold.opacity(0.35), lineWidth: 1.2)
                .padding(24)
        }
        .frame(width: 118, height: 118)
        .plGlow(radius: 13)
    }
}

// MARK: - Page 3 — Michelin stars

/// Three stars in a Michelin-red-to-gold gradient, springing in one after another.
struct OnboardingStarsMotif: View {
    let revealed: Bool

    private let sizes: [CGFloat] = [46, 66, 46]
    private let lifts: [CGFloat] = [12, -10, 12]

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color.plGold.opacity(0.12), .clear],
                                     center: .center, startRadius: 20, endRadius: 140))
                .frame(width: 280, height: 280)

            HStack(alignment: .center, spacing: 20) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "star.fill")
                        .font(.system(size: sizes[index]))
                        .foregroundStyle(
                            LinearGradient(colors: [Color.plMichelin, Color.plGoldDeep, Color.plGold],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .plGlow(radius: 13)
                        .scaleEffect(revealed ? 1 : 0.1)
                        .opacity(revealed ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.55)
                            .delay(0.45 + Double(index) * 0.18),
                                   value: revealed)
                        .offset(y: lifts[index])
                }
            }
        }
    }
}
