import SwiftUI
import WidgetKit
import SuiWidgetKit

public struct MediumWidgetView: View {
    public let entry: SuiWidgetEntry
    public init(entry: SuiWidgetEntry) { self.entry = entry }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    SuiGlyph(size: 12)
                    if let label = entry.wallet?.displayString(for: entry.configuration.walletDisplay) {
                        Text(label)
                            .font(SuiTypography.mono(9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    PetSlotView()
                }
                PortfolioValueText(value: entry.portfolio?.totalUSD ?? 0, currency: entry.configuration.currency, size: 26)
                DeltaGlyph(percent: entry.portfolio?.change24hPercent ?? 0)
                PixelSparkline(
                    points: entry.sparklinePoints.map { ($0 as NSDecimalNumber).doubleValue },
                    color: suiDeltaColor(entry.portfolio?.change24hPercent ?? 0)
                )
                .frame(height: 18)
                Spacer()
                Text(refreshLabel)
                    .font(SuiTypography.mono(8))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("TOKENS").font(SuiTypography.mono(8, weight: .bold)).foregroundStyle(.secondary)
                let holdings = entry.portfolio?.topHoldings ?? []
                ForEach(holdings.prefix(3), id: \.symbol) { h in
                    tokenRow(h)
                }
                if holdings.isEmpty {
                    Text("No tokens yet")
                        .font(SuiTypography.body(10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .homeWidgetChrome(watermarkSize: 48)
        .animation(.default, value: entry)
        .widgetURL(URL(string: "suiwidget://wallet/primary"))
    }

    private func tokenRow(_ holding: HoldingSummary) -> some View {
        HStack(spacing: 4) {
            Text(holding.symbol).font(SuiTypography.body(10, weight: .bold))
            Spacer()
            Text(WidgetCurrencyFormatter.compact(usdValue: holding.usdValue, currency: entry.configuration.currency))
                .font(SuiTypography.mono(9))
                .contentTransition(.numericText())
            DeltaGlyph(percent: holding.change24h, size: 9)
        }
    }

    private var refreshLabel: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "↻ \(f.string(from: entry.date))"
    }
}
