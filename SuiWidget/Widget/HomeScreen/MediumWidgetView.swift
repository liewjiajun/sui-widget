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
                    Text(entry.wallet?.label ?? "SUI")
                        .font(SuiTypography.mono(9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    PetSlotView()
                }
                PortfolioValueText(value: entry.portfolio?.totalUSD ?? 0, size: 26)
                DeltaGlyph(percent: entry.portfolio?.change24hPercent ?? 0)
                Spacer()
                Text(refreshLabel).font(SuiTypography.mono(8)).foregroundStyle(.secondary)
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
        .widgetURL(URL(string: "suiwidget://wallet/primary"))
    }

    private func tokenRow(_ holding: HoldingSummary) -> some View {
        HStack(spacing: 4) {
            Text(holding.symbol).font(SuiTypography.body(10, weight: .bold))
            Spacer()
            Text(usd(holding.usdValue)).font(SuiTypography.mono(9))
            DeltaGlyph(percent: holding.change24h, size: 9)
        }
    }

    private var refreshLabel: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "↻ \(f.string(from: entry.date))"
    }

    private func usd(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f.string(from: value as NSDecimalNumber) ?? "$0"
    }
}
