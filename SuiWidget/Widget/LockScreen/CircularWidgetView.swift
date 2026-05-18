import SwiftUI
import WidgetKit
import SuiWidgetKit

public struct CircularWidgetView: View {
    public let entry: SuiWidgetEntry
    public init(entry: SuiWidgetEntry) { self.entry = entry }

    public var body: some View {
        let pct = entry.portfolio?.change24hPercent ?? 0
        VStack(spacing: 1) {
            Text("24H").font(SuiTypography.mono(8, weight: .bold))
            Text(deltaGlyph(pct))
                .font(SuiTypography.display(14, weight: .heavy))
            Text(String(format: "%.1f%%", abs(pct)))
                .font(SuiTypography.mono(10, weight: .bold))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) { Color.clear }
        .accessibilityLabel("Portfolio 24 hours \(pct >= 0 ? "up" : "down") \(String(format: "%.1f", abs(pct))) percent")
    }

    private func deltaGlyph(_ pct: Double) -> String {
        if pct > 0.05 { return "▲" }
        if pct < -0.05 { return "▼" }
        return "~"
    }
}
