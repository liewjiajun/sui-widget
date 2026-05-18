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
                Text(entry.wallet?.label ?? "SUI")
                    .font(SuiTypography.mono(10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                PetSlotView()
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                PortfolioValueText(value: entry.portfolio?.totalUSD ?? 0, size: 40)
                DeltaGlyph(percent: entry.portfolio?.change24hPercent ?? 0, size: 12)
                Spacer()
            }
            Divider()
            tokensRow
            Spacer().frame(height: 4)
            Text("NFTs · \(entry.topNFTs.count)").font(SuiTypography.mono(8, weight: .bold)).foregroundStyle(.secondary)
            nftRow
            Spacer().frame(height: 4)
            if let headline = entry.topNews.first {
                Text("NEWS").font(SuiTypography.mono(8, weight: .bold)).foregroundStyle(.secondary)
                Text(headline.title)
                    .font(SuiTypography.body(11, weight: .semibold))
                    .lineLimit(2)
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
                    Text(h.symbol).font(SuiTypography.body(11, weight: .bold))
                    Spacer()
                    Text(usd(h.usdValue))
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
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(SuiColor.suiBlue.opacity(0.18))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(nft.name.prefix(2)))
                            .font(SuiTypography.mono(8, weight: .bold))
                            .foregroundStyle(SuiColor.suiDeep)
                    )
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

    private func usd(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f.string(from: value as NSDecimalNumber) ?? "$0"
    }
}
