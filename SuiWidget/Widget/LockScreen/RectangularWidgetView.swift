import SwiftUI
import WidgetKit
import SuiWidgetKit

public struct RectangularWidgetView: View {
    public let entry: SuiWidgetEntry
    public init(entry: SuiWidgetEntry) { self.entry = entry }

    public var body: some View {
        let value = entry.portfolio?.totalUSD ?? 0
        let pct = entry.portfolio?.change24hPercent ?? 0
        VStack(alignment: .leading, spacing: 1) {
            Text("PORTFOLIO").font(SuiTypography.mono(8, weight: .bold))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formatted(value))
                    .font(SuiTypography.display(16, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(deltaGlyph(pct))
                    .font(SuiTypography.display(11, weight: .heavy))
                Text(String(format: "%.1f%%", abs(pct)))
                    .font(SuiTypography.mono(10, weight: .bold))
            }
            Text("↻ \(refreshLabel(entry.date))")
                .font(SuiTypography.mono(8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityLabel("Portfolio \(formatted(value)), \(pct >= 0 ? "up" : "down") \(String(format: "%.1f", abs(pct))) percent")
    }

    private func formatted(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f.string(from: value as NSDecimalNumber) ?? "$0"
    }

    private func deltaGlyph(_ pct: Double) -> String {
        if pct > 0.05 { return "▲" }
        if pct < -0.05 { return "▼" }
        return "~"
    }

    private func refreshLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
