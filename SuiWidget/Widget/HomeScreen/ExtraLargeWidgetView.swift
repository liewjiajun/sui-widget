import SwiftUI
import WidgetKit
import SuiWidgetKit

public struct ExtraLargeWidgetView: View {
    public let entry: SuiWidgetEntry
    public init(entry: SuiWidgetEntry) { self.entry = entry }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top: portfolio hero
            HStack(spacing: 8) {
                SuiGlyph(size: 16)
                Text(entry.wallet?.label ?? "SUI")
                    .font(SuiTypography.mono(11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                PortfolioValueText(value: entry.portfolio?.totalUSD ?? 0, size: 46)
                DeltaGlyph(percent: entry.portfolio?.change24hPercent ?? 0, size: 12)
            }

            Divider()

            // 3-column dashboard
            HStack(alignment: .top, spacing: 12) {
                column(title: "TOKENS · \(entry.portfolio?.topHoldings.count ?? 0)") {
                    ForEach((entry.portfolio?.topHoldings ?? []).prefix(4), id: \.symbol) { h in
                        HStack(spacing: 4) {
                            Text(h.symbol).font(SuiTypography.body(11, weight: .bold))
                            Spacer()
                            Text(usd(h.usdValue))
                                .font(SuiTypography.mono(10))
                                .contentTransition(.numericText())
                            DeltaGlyph(percent: h.change24h, size: 9)
                        }
                    }
                }
                column(title: "NFTs · \(entry.topNFTs.count)") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                        ForEach(entry.topNFTs.prefix(4)) { nft in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(SuiColor.suiBlue.opacity(0.18))
                                .frame(height: 36)
                                .overlay(
                                    Text(String(nft.name.prefix(2)))
                                        .font(SuiTypography.mono(8, weight: .bold))
                                        .foregroundStyle(SuiColor.suiDeep)
                                )
                        }
                    }
                }
                column(title: "NEWS · \(entry.topNews.count)") {
                    ForEach(entry.topNews.prefix(3)) { item in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                                .font(SuiTypography.body(10, weight: .semibold))
                                .lineLimit(2)
                            Text(item.source.rawValue.uppercased())
                                .font(SuiTypography.mono(7))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Staking footer — the user's explicit ask
            if let stakes = entry.stakes, stakes.positionCount > 0 {
                StakedFooter(stakes: stakes)
            } else {
                StakedFooter(stakes: StakeSummary(totalSUI: 0, positionCount: 0, weightedAPY: nil))
                    .opacity(0.4)
            }

            HStack {
                Spacer()
                Text(refreshLabel)
                    .font(SuiTypography.mono(8))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
        .padding(12)
        .animation(.default, value: entry)
        .widgetURL(URL(string: "suiwidget://wallet/primary"))
    }

    @ViewBuilder
    private func column<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(SuiTypography.mono(8, weight: .bold)).foregroundStyle(.secondary)
            content()
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
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
