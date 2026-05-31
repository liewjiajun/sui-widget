import SwiftUI
import SuiWidgetKit

/// "Earning" section for the Portfolio screen — shows where the user's tokens
/// are deployed (liquid staking, lending, LSTs) grouped by category → protocol.
/// The USD value of every position here is ALSO part of the portfolio total
/// above the donut; this section answers "where are my tokens working?" without
/// double-counting (DeFi rows are filtered out of the plain TOKENS list).
struct EarningSectionView: View {
    /// The DeFi-position subset of the wallet's holdings (dappName != nil).
    let positions: [CachedTokenHolding]
    /// Per-coinType slice colours shared with the donut, for the row avatars.
    let colorByCoinType: [String: Color]

    private struct ProtocolGroup: Identifiable {
        let id: String                 // "category|dapp"
        let category: String
        let dappName: String
        let holdings: [CachedTokenHolding]
        var subtotal: Decimal { holdings.reduce(Decimal(0)) { $0 + $1.valueUSD } }
    }

    var body: some View {
        if !positions.isEmpty {
            VStack(alignment: .leading, spacing: SuiSpacing.s2) {
                header
                VStack(spacing: SuiSpacing.s3) {
                    ForEach(groups) { group in
                        groupCard(group)
                    }
                }
            }
        }
    }

    private var totalDeployed: Decimal {
        positions.reduce(Decimal(0)) { $0 + $1.valueUSD }
    }

    private var header: some View {
        HStack(spacing: SuiSpacing.s2) {
            Image(systemName: "leaf.arrow.triangle.circlepath")
                .font(SuiTypography.body(12))
                .foregroundStyle(SuiColor.up)
            Text("EARNING")
                .font(SuiTypography.mono(10, weight: .bold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(usd(totalDeployed)) deployed")
                .font(SuiTypography.mono(10, weight: .bold))
                .foregroundStyle(SuiColor.up)
        }
    }

    /// Groups by (category, dappName), sorted by descending subtotal so the
    /// largest position cluster leads.
    private var groups: [ProtocolGroup] {
        let grouped = Dictionary(grouping: positions) { holding -> String in
            let cat = holding.defiCategory ?? "Other"
            let dapp = holding.dappName ?? "Protocol"
            return "\(cat)|\(dapp)"
        }
        return grouped.map { key, holdings in
            let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
            return ProtocolGroup(
                id: key,
                category: parts.first ?? "Other",
                dappName: parts.count > 1 ? parts[1] : "Protocol",
                holdings: holdings.sorted { $0.valueUSD > $1.valueUSD }
            )
        }
        .sorted { $0.subtotal > $1.subtotal }
    }

    @ViewBuilder
    private func groupCard(_ group: ProtocolGroup) -> some View {
        VStack(alignment: .leading, spacing: SuiSpacing.s2) {
            // Protocol header: name + category pill + subtotal.
            HStack(spacing: SuiSpacing.s2) {
                Image(systemName: categoryGlyph(group.category))
                    .font(SuiTypography.body(12))
                    .foregroundStyle(SuiColor.suiBlue)
                Text(group.dappName)
                    .font(SuiTypography.body(13, weight: .bold))
                Text(group.category)
                    .font(SuiTypography.mono(8, weight: .bold))
                    .padding(.horizontal, SuiSpacing.s1)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(SuiColor.up.opacity(0.16)))
                    .foregroundStyle(SuiColor.up)
                Spacer()
                Text(usd(group.subtotal))
                    .font(SuiTypography.mono(11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            ForEach(group.holdings, id: \.id) { holding in
                NavigationLink {
                    TokenDetailView(holding: holding)
                } label: {
                    EarningRowView(holding: holding, sliceColor: colorByCoinType[holding.coinType])
                }
                .buttonStyle(.plain)
            }
        }
        .padding(SuiSpacing.s3)
        .background(
            RoundedRectangle(cornerRadius: SuiSpacing.cardRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func categoryGlyph(_ category: String) -> String {
        switch category {
        case KnownProtocols.Category.liquidStaking.rawValue: return KnownProtocols.Category.liquidStaking.systemImage
        case KnownProtocols.Category.lending.rawValue: return KnownProtocols.Category.lending.systemImage
        default: return "circle.grid.cross"
        }
    }

    private func usd(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = value < 1 && value > 0 ? 4 : 2
        return f.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

/// A single position row inside an Earning protocol group.
private struct EarningRowView: View {
    let holding: CachedTokenHolding
    let sliceColor: Color?

    var body: some View {
        HStack(spacing: SuiSpacing.s2) {
            ZStack {
                Circle().fill((sliceColor ?? SuiColor.suiBlue).opacity(0.18))
                Text(holding.symbol.first.map { String($0).uppercased() } ?? "?")
                    .font(SuiTypography.display(11))
                    .foregroundStyle(sliceColor ?? SuiColor.suiBlue)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(holding.symbol).font(SuiTypography.body(13, weight: .semibold))
                Text(balanceLabel).font(SuiTypography.mono(9)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(valueLabel).font(SuiTypography.display(12))
                if !holding.isTracked {
                    Text("est.")
                        .font(SuiTypography.mono(7, weight: .bold))
                        .foregroundStyle(SuiColor.flat)
                }
            }
            Image(systemName: "chevron.right")
                .font(SuiTypography.body(10))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private var balanceLabel: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 4
        let str = f.string(from: holding.balance as NSDecimalNumber) ?? "0"
        return "\(str) \(holding.symbol)"
    }

    private var valueLabel: String {
        guard holding.priceUSD != nil else { return "—" }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        return f.string(from: holding.valueUSD as NSDecimalNumber) ?? "$0"
    }
}

#Preview("Earning section") {
    ScrollView {
        EarningSectionView(
            positions: [
                CachedTokenHolding(
                    coinType: "0xb::hasui::HASUI", symbol: "haSUI", name: "Haedal · Sui",
                    balance: 408.2, decimals: 9, priceUSD: 1.45, priceChange24h: 2.4,
                    isTracked: true, dappName: "Haedal",
                    underlyingCoinType: "0x2::sui::SUI", defiCategory: "Liquid staking"
                ),
                CachedTokenHolding(
                    coinType: "0xf::afsui::AFSUI", symbol: "afSUI", name: "Aftermath · Sui",
                    balance: 500, decimals: 9, priceUSD: 1.50, priceChange24h: 2.1,
                    isTracked: true, dappName: "Aftermath",
                    underlyingCoinType: "0x2::sui::SUI", defiCategory: "Liquid staking"
                ),
                CachedTokenHolding(
                    coinType: "0xe::reserve::MarketCoin<usdc>", symbol: "sUSDC", name: "Scallop · USD Coin",
                    balance: 280, decimals: 6, priceUSD: 1.0, priceChange24h: 0.0,
                    isTracked: true, dappName: "Scallop",
                    underlyingCoinType: "0x5::coin::COIN", defiCategory: "Lending"
                ),
            ],
            colorByCoinType: [:]
        )
        .padding()
    }
}
