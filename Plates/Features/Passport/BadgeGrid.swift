import SwiftUI

/// Three-column badge cabinet. Earned badges glow in their tier's metal;
/// unearned badges sit dimmed behind a thin progress ring and a lock.
/// Tapping any badge opens a detail sheet.
struct BadgeGrid: View {
    var badges: [Badge]

    @State private var selected: Badge?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12),
                                count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(badges) { badge in
                Button {
                    Haptics.tap()
                    selected = badge
                } label: {
                    BadgeCell(badge: badge)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityText(for: badge))
            }
        }
        .sheet(item: $selected) { badge in
            BadgeDetailSheet(badge: badge)
        }
    }

    private func accessibilityText(for badge: Badge) -> String {
        badge.earned
            ? "\(badge.name), earned"
            : "\(badge.name), locked, \(Int(badge.progress * 100)) percent complete"
    }
}

// MARK: - Cell

private struct BadgeCell: View {
    let badge: Badge

    var body: some View {
        VStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(Color.plSurfaceElevated)

                if badge.earned {
                    Circle()
                        .strokeBorder(badge.tier.accent.opacity(0.65), lineWidth: 1.5)
                    Image(systemName: badge.symbol)
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(badge.tier.accent)
                        .plGlow(badge.tier.accent, radius: 7)
                } else {
                    Circle()
                        .strokeBorder(Color.plStroke, lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: max(0, min(1, badge.progress)))
                        .stroke(Color.plGold.opacity(0.75),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(1.25)
                    Image(systemName: badge.symbol)
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(Color.plTextSecondary.opacity(0.45))
                }
            }
            .frame(width: 62, height: 62)
            .overlay(alignment: .bottomTrailing) {
                if !badge.earned {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.plTextSecondary)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.plSurface))
                        .overlay(Circle().strokeBorder(Color.plStroke, lineWidth: 1))
                }
            }

            Text(badge.name)
                .font(.caption.weight(.medium))
                .foregroundStyle(badge.earned ? Color.plText : Color.plTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.plSurface))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.plStroke, lineWidth: 1))
        .opacity(badge.earned ? 1 : 0.85)
    }
}

// MARK: - Detail sheet

private struct BadgeDetailSheet: View {
    let badge: Badge

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.plSurfaceElevated)

                if badge.earned {
                    Circle()
                        .strokeBorder(badge.tier.accent.opacity(0.65), lineWidth: 2)
                    Image(systemName: badge.symbol)
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(badge.tier.accent)
                        .plGlow(badge.tier.accent, radius: 12)
                } else {
                    Circle()
                        .strokeBorder(Color.plStroke, lineWidth: 3.5)
                    Circle()
                        .trim(from: 0, to: max(0, min(1, badge.progress)))
                        .stroke(Color.plGold.opacity(0.8),
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(1.75)
                    Image(systemName: badge.symbol)
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(Color.plTextSecondary.opacity(0.5))
                }
            }
            .frame(width: 116, height: 116)
            .padding(.top, 10)

            VStack(spacing: 8) {
                Text(badge.name)
                    .font(.plDisplay(27))
                    .foregroundStyle(Color.plText)

                Text(badge.tier.label.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(badge.tier.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(badge.tier.accent.opacity(0.14)))
            }

            Text(badge.blurb)
                .font(.subheadline)
                .foregroundStyle(Color.plTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            if badge.earned {
                Label("Collected", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(badge.tier.accent)
                    .padding(.top, 2)
            } else {
                VStack(spacing: 7) {
                    ProgressView(value: max(0, min(1, badge.progress)))
                        .tint(.plGold)
                    Text("\(Int(badge.progress * 100))% of the way there")
                        .font(.caption)
                        .foregroundStyle(Color.plTextSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .presentationDetents([.height(400)])
        .presentationBackground(Color.plSurface)
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Tier styling

private extension BadgeTier {
    /// Earned badges are gold; Michelin-tier badges use the Michelin red.
    var accent: Color {
        self == .michelin ? .plMichelin : .plGold
    }

    var label: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .michelin: return "Michelin"
        }
    }
}
