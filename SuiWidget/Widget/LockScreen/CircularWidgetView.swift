import SwiftUI
import WidgetKit
import SuiWidgetKit

public struct CircularWidgetView: View {
    public let entry: SuiWidgetEntry
    public init(entry: SuiWidgetEntry) { self.entry = entry }

    public var body: some View {
        let pct = entry.portfolio?.change24hPercent ?? 0
        VStack(spacing: 1) {
            Text("24H")
                .font(SuiTypography.pixelDisplay(10))
            Text(deltaGlyph(pct))
                .font(SuiTypography.pixelDisplay(18))
                .contentTransition(.numericText())
            Text(String(format: "%.1f%%", abs(pct)))
                .font(SuiTypography.pixelDisplay(13))
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) { Color.clear }
        .animation(.default, value: entry)
        .accessibilityLabel("Portfolio 24 hours \(pct >= 0 ? "up" : "down") \(String(format: "%.1f", abs(pct))) percent")
    }

    private func deltaGlyph(_ pct: Double) -> String {
        if pct > 0.05 { return "▲" }
        if pct < -0.05 { return "▼" }
        return "~"
    }
}
