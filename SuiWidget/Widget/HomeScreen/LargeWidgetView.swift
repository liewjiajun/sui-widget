import SwiftUI
import WidgetKit
import SuiWidgetKit

public struct LargeWidgetView: View {
    public let entry: SuiWidgetEntry
    public init(entry: SuiWidgetEntry) { self.entry = entry }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                SuiGlyph(size: 14)
                if let label = entry.wallet?.displayString(for: entry.configuration.walletDisplay) {
                    Text(label)
                        .font(SuiTypography.mono(10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                PortfolioValueText(value: entry.portfolio?.totalUSD ?? 0, currency: entry.configuration.currency, size: 40)
                DeltaGlyph(percent: entry.portfolio?.change24hPercent ?? 0, size: 12)
                Spacer()
            }
            PixelSparkline(
                points: entry.sparklinePoints.map { ($0 as NSDecimalNumber).doubleValue },
                color: suiDeltaColor(entry.portfolio?.change24hPercent ?? 0)
            )
            .frame(height: 28)
            Divider()
            tokensRow
            Spacer().frame(height: 4)
            Text("NFTs · \(entry.topNFTs.count)").font(SuiTypography.mono(8, weight: .bold)).foregroundStyle(.secondary)
            nftRow
            Spacer().frame(height: 4)
            if let headline = entry.topNews.first {
                Text("NEWS").font(SuiTypography.mono(8, weight: .bold)).foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: 6) {
                    NewsHeroImage(item: headline, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(headline.title)
                            .font(SuiTypography.body(11, weight: .semibold))
                            .lineLimit(2)
                        Text(headline.source.displayLabel.uppercased())
                            .font(SuiTypography.mono(7, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Text(refreshLabel)
                .font(SuiTypography.mono(8))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
        .padding(10)
        .homeWidgetChrome(watermarkSize: 64)
        .animation(.default, value: entry)
        .widgetURL(URL(string: "suiwidget://wallet/primary"))
    }

    private var tokensRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("TOKENS").font(SuiTypography.mono(8, weight: .bold)).foregroundStyle(.secondary)
            ForEach((entry.portfolio?.topHoldings ?? []).prefix(3), id: \.symbol) { h in
                HStack(spacing: 4) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(h.symbol).font(SuiTypography.body(11, weight: .bold))
                        if let dapp = h.dappName {
                            Text("via \(dapp)")
                                .font(SuiTypography.mono(7, weight: .bold))
                                .foregroundStyle(SuiColor.suiBlue)
                        }
                    }
                    Spacer()
                    Text(WidgetCurrencyFormatter.compact(usdValue: h.usdValue, currency: entry.configuration.currency))
                        .font(SuiTypography.mono(10))
                        .contentTransition(.numericText())
                    DeltaGlyph(percent: h.change24h, size: 9)
                }
            }
        }
    }

    private var nftRow: some View {
        HStack(spacing: 6) {
            ForEach(entry.topNFTs.prefix(4)) { nft in
                WidgetNFTThumbnail(nft: nft, size: 44)
            }
            ForEach(0..<max(0, 4 - entry.topNFTs.count), id: \.self) { _ in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(SuiColor.flat.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    .frame(width: 44, height: 44)
            }
        }
    }

    private var refreshLabel: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "↻ \(f.string(from: entry.date))"
    }
}
