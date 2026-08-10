import SwiftUI
import UIKit

// MARK: - Palette

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }

    static let plBackground = Color(hex: 0x0A0A0F)
    static let plSurface = Color(hex: 0x14141B)
    static let plSurfaceElevated = Color(hex: 0x1C1C25)
    static let plStroke = Color(hex: 0x2A2A36)
    static let plGold = Color(hex: 0xE8B84B)
    static let plGoldDeep = Color(hex: 0xC9962E)
    static let plMichelin = Color(hex: 0xD64541)
    static let plText = Color(hex: 0xF5F2EA)
    static let plTextSecondary = Color(hex: 0x8E8E99)
}

extension LinearGradient {
    static let plGold = LinearGradient(colors: [Color(hex: 0xF2CE6B), Color(hex: 0xC9962E)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - Type

extension Font {
    /// Serif display face — restaurant names and big headers.
    static func plDisplay(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    /// Rounded numerals — money, counts, stats.
    static func plNumber(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Surfaces & effects

private struct PlCard: ViewModifier {
    var padding: CGFloat
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.plSurface))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.plStroke, lineWidth: 1))
    }
}

extension View {
    func plCard(padding: CGFloat = 16) -> some View { modifier(PlCard(padding: padding)) }
    func plGlow(_ color: Color = .plGold, radius: CGFloat = 12) -> some View {
        shadow(color: color.opacity(0.55), radius: radius)
    }
}

struct PlPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(hex: 0x14100A))
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(LinearGradient.plGold))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

// MARK: - Money

/// Formats an amount in a currency, dropping cents once amounts get large.
func plMoney(_ amount: Decimal, _ code: String) -> String {
    let digits = abs(amount.plDouble) >= 100 ? 0 : 2
    return amount.formatted(.currency(code: code).precision(.fractionLength(digits)))
}

// MARK: - Haptics

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func celebrate() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
