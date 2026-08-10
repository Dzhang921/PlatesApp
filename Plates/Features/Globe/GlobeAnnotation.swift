import SwiftUI

/// A single point of light on the night globe. Fixed screen-point size so it
/// stays legible from orbit; the radial halo (not just the core) is what reads
/// when zoomed way out.
///
/// - Normal plates: gold core with a soft gold glow.
/// - Michelin plates: slightly larger, red-tinted glow, tiny star on the core.
/// - Repeat visits: slightly larger and brighter, capped at +3 visits.
struct GlobeAnnotationDot: View {
    let isMichelin: Bool
    let visitCount: Int

    /// 0...3 — extra presence for repeat visits, capped so dots never balloon.
    private var visitBoost: CGFloat {
        CGFloat(min(max(visitCount - 1, 0), 3))
    }

    private var coreSize: CGFloat {
        (isMichelin ? 12 : 9) + visitBoost * 1.1
    }

    private var haloSize: CGFloat { coreSize * 3.4 }

    private var glowColor: Color { isMichelin ? .plMichelin : .plGold }

    private var haloOpacity: Double {
        min(0.42 + Double(visitBoost) * 0.09, 0.7)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [glowColor.opacity(haloOpacity),
                                              glowColor.opacity(0)],
                                     center: .center,
                                     startRadius: 1,
                                     endRadius: haloSize / 2))
                .frame(width: haloSize, height: haloSize)

            Circle()
                .fill(LinearGradient.plGold)
                .frame(width: coreSize, height: coreSize)
                .overlay(Circle().strokeBorder(Color.plText.opacity(0.6), lineWidth: 0.75))
                .plGlow(glowColor, radius: isMichelin ? 10 : 7)

            if isMichelin {
                Image(systemName: "star.fill")
                    .font(.system(size: coreSize * 0.5, weight: .black))
                    .foregroundStyle(Color.plMichelin)
                    .shadow(color: Color.plBackground.opacity(0.35), radius: 0.5)
            }
        }
        .frame(width: 44, height: 44)
        .contentShape(Circle())
    }
}
