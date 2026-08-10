import SwiftUI
import Charts

/// Twelve gold bars, January through December, for one year of spending.
/// The current month is drawn brighter with a small glowing cap.
struct StatsMonthlyChart: View {
    let monthlySpend: [Decimal]
    let year: Int
    let currencyCode: String

    private static let monthLabels = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    private struct MonthBar: Identifiable {
        let index: Int
        let label: String
        let value: Double
        let isCurrent: Bool
        var id: Int { index }
    }

    private var currentMonthIndex: Int? {
        let now = Date()
        let calendar = Calendar.current
        guard calendar.component(.year, from: now) == year else { return nil }
        return calendar.component(.month, from: now) - 1
    }

    private var bars: [MonthBar] {
        let current = currentMonthIndex
        return (0..<12).map { index in
            let amount = index < monthlySpend.count ? monthlySpend[index] : 0
            return MonthBar(index: index,
                            label: Self.monthLabels[index],
                            value: amount.plDouble,
                            isCurrent: index == current)
        }
    }

    private var yDomainMax: Double {
        let peak = bars.map(\.value).max() ?? 0
        return max(peak * 1.18, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StatsSectionLabel("Monthly spend")

            Chart(bars) { bar in
                BarMark(
                    x: .value("Month", bar.label),
                    y: .value("Spent", bar.value),
                    width: .ratio(0.62)
                )
                .cornerRadius(4)
                .foregroundStyle(LinearGradient.plGold)
                .opacity(bar.isCurrent ? 1 : 0.55)
                .annotation(position: .top, spacing: 4) {
                    if bar.isCurrent && bar.value > 0 {
                        Circle()
                            .fill(Color.plGold)
                            .frame(width: 4, height: 4)
                            .plGlow(.plGold, radius: 4)
                    }
                }
            }
            .chartXScale(domain: Self.monthLabels)
            .chartYScale(domain: 0...yDomainMax)
            .chartXAxis {
                AxisMarks(values: Self.monthLabels) { _ in
                    AxisValueLabel()
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.plTextSecondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                        .foregroundStyle(Color.plStroke.opacity(0.55))
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(compactCurrency(amount))
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.plTextSecondary)
                        }
                    }
                }
            }
            .frame(height: 190)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .plCard(padding: 18)
    }

    private func compactCurrency(_ value: Double) -> String {
        value.formatted(.currency(code: currencyCode)
            .notation(.compactName)
            .precision(.fractionLength(0)))
    }
}
