import SwiftUI
import WidgetKit

// MARK: - Local palette (widget target cannot import the app's Theme)

private extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

private enum PLColor {
    static let background = Color(hex: 0x0A0A0F)
    static let surface = Color(hex: 0x14141B)
    static let gold = Color(hex: 0xE8B84B)
    static let michelin = Color(hex: 0xD64541)
    static let text = Color(hex: 0xF5F2EA)
    static let secondary = Color(hex: 0x8E8E99)
}

// MARK: - Timeline

struct PlatesEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct PlatesOverviewProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlatesEntry {
        PlatesEntry(date: Date(), snapshot: WidgetSnapshotLoader.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (PlatesEntry) -> Void) {
        let snapshot = context.isPreview
            ? WidgetSnapshotLoader.sample
            : WidgetSnapshotLoader.loadOrSample()
        completion(PlatesEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlatesEntry>) -> Void) {
        let entry = PlatesEntry(date: Date(), snapshot: WidgetSnapshotLoader.loadOrSample())
        let refresh = Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

// MARK: - Widget

struct PlatesOverviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PlatesOverviewWidget", provider: PlatesOverviewProvider()) { entry in
            PlatesOverviewEntryView(entry: entry)
        }
        .configurationDisplayName("Your Collection")
        .description("Plates, stars, and this year's spend.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}

struct PlatesOverviewEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PlatesEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            AccessoryCircularStarsView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Color.clear }
        case .systemMedium:
            MediumOverviewView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { PLColor.background }
        default:
            SmallOverviewView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { PLColor.background }
        }
    }
}

// MARK: - Shared formatting

private func spendText(_ snapshot: WidgetSnapshot) -> String {
    snapshot.yearSpendHome.formatted(
        .currency(code: snapshot.homeCurrencyCode).precision(.fractionLength(0))
    )
}

private func countriesText(_ count: Int) -> String {
    count == 1 ? "1 country" : "\(count) countries"
}

// MARK: - System small

private struct SmallOverviewView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(snapshot.plateCount)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(PLColor.text)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("plates")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(PLColor.secondary)
                .textCase(.uppercase)
                .kerning(1.2)

            Spacer(minLength: 6)

            HStack(spacing: 5) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(PLColor.gold)
                Text("\(snapshot.starCount)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(PLColor.text)
            }

            HStack(spacing: 5) {
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PLColor.secondary)
                Text(countriesText(snapshot.countryCount))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(PLColor.secondary)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - System medium

private struct MediumOverviewView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(snapshot.plateCount)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(PLColor.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("plates")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(PLColor.secondary)
                        .textCase(.uppercase)
                        .kerning(1.1)
                }

                Spacer(minLength: 6)

                Text(spendText(snapshot))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(PLColor.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("this year")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(PLColor.secondary)
                    .padding(.top, 1)
            }

            Rectangle()
                .fill(PLColor.secondary.opacity(0.25))
                .frame(width: 1)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PLColor.gold)
                    Text("\(snapshot.starCount)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(PLColor.text)
                    Text("Michelin stars")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(PLColor.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text(snapshot.topCuisineEmoji)
                        .font(.system(size: 15))
                    Text(snapshot.topCuisineName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(PLColor.text)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PLColor.secondary)
                    Text(countriesText(snapshot.countryCount))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(PLColor.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Accessory circular

private struct AccessoryCircularStarsView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("\(snapshot.starCount)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .widgetAccentable()
        }
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    PlatesOverviewWidget()
} timeline: {
    PlatesEntry(date: Date(), snapshot: WidgetSnapshotLoader.sample)
}

#Preview("Medium", as: .systemMedium) {
    PlatesOverviewWidget()
} timeline: {
    PlatesEntry(date: Date(), snapshot: WidgetSnapshotLoader.sample)
}

#Preview("Circular", as: .accessoryCircular) {
    PlatesOverviewWidget()
} timeline: {
    PlatesEntry(date: Date(), snapshot: WidgetSnapshotLoader.sample)
}
