import SwiftUI
import WidgetKit
import SuiWidgetKit

public struct SmallWidgetView: View {
    public let entry: SuiWidgetEntry

    public init(entry: SuiWidgetEntry) { self.entry = entry }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                SuiGlyph(size: 12)
                Text(entry.wallet?.label ?? "SUI")
                    .font(SuiTypography.mono(9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if entry.isStale {
                    Text("⌛").font(SuiTypography.mono(9))
                }
            }
            Spacer()
            PortfolioValueText(value: entry.portfolio?.totalUSD ?? 0, size: 24)
            DeltaGlyph(percent: entry.portfolio?.change24hPercent ?? 0)
            PixelSparkline(
                points: entry.sparklinePoints.map { ($0 as NSDecimalNumber).doubleValue },
                color: deltaColor(entry.portfolio?.change24hPercent ?? 0)
            )
            .frame(height: 16)
            Text(refreshLabel)
                .font(SuiTypography.mono(8))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "suiwidget://wallet/primary"))
    }

    private var refreshLabel: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "↻ \(f.string(from: entry.date))"
    }

    private func deltaColor(_ d: Double) -> Color {
        d > 0 ? SuiColor.up : (d < 0 ? SuiColor.down : SuiColor.flat)
    }
}
