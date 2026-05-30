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
                Text(WidgetCurrencyFormatter.compact(usdValue: value, currency: entry.configuration.currency))
                    .font(SuiTypography.pixelDisplay(22))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                Text(deltaGlyph(pct))
                    .font(SuiTypography.pixelDisplay(15))
                    .contentTransition(.numericText())
                Text(String(format: "%.1f%%", abs(pct)))
                    .font(SuiTypography.pixelDisplay(14))
                    .contentTransition(.numericText())
            }
            Text("↻ \(refreshLabel(entry.date))")
                .font(SuiTypography.mono(8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        // Lock-screen widgets stay monochrome — iOS tints them — but every
        // widget body must install a container background on iOS 17+.
        .containerBackground(for: .widget) { Color.clear }
        .animation(.default, value: entry)
        .accessibilityLabel("Portfolio \(formatted(value)), \(pct >= 0 ? "up" : "down") \(String(format: "%.1f", abs(pct))) percent")
    }

    private func formatted(_ value: Decimal) -> String {
        WidgetCurrencyFormatter.compact(usdValue: value, currency: entry.configuration.currency)
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
