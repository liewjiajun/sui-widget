import SwiftUI
import WidgetKit
import SuiWidgetKit

public struct InlineWidgetView: View {
    public let entry: SuiWidgetEntry
    public init(entry: SuiWidgetEntry) { self.entry = entry }

    public var body: some View {
        let value = entry.portfolio?.totalUSD ?? 0
        let pct = entry.portfolio?.change24hPercent ?? 0
        Text("⬡ SUI \(formatted(value)) \(deltaGlyph(pct)) \(String(format: "%.1f%%", abs(pct)))")
            .font(SuiTypography.pixelDisplay(15))
            .contentTransition(.numericText())
            // Inline accessory widgets must install a container background
            // (iOS 17+ widget API requirement) — clear lets iOS tint freely.
            .containerBackground(for: .widget) { Color.clear }
            .animation(.default, value: entry)
            .accessibilityLabel("SUI portfolio \(formatted(value)) \(pct > 0 ? "up" : pct < 0 ? "down" : "flat") \(String(format: "%.1f", abs(pct))) percent")
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
}
