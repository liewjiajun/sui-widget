import WidgetKit
import AppIntents
import SwiftData
import Foundation
import SuiWidgetKit

public struct SuiTimelineProvider: AppIntentTimelineProvider {
    public typealias Entry = SuiWidgetEntry
    public typealias Intent = SuiWidgetConfigurationIntent

    public init() {}

    public func placeholder(in context: Context) -> SuiWidgetEntry {
        SuiWidgetEntry.placeholder
    }

    public func snapshot(for configuration: SuiWidgetConfigurationIntent, in context: Context) async -> SuiWidgetEntry {
        if context.isPreview {
            return .preview
        }
        return await buildEntry(configuration: configuration)
    }

    public func timeline(for configuration: SuiWidgetConfigurationIntent, in context: Context) async -> Timeline<SuiWidgetEntry> {
        let entry = await buildEntry(configuration: configuration)
        let nextRefresh = Date().addingTimeInterval(configuration.refresh.seconds)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    private func buildEntry(configuration: SuiWidgetConfigurationIntent) async -> SuiWidgetEntry {
        do {
            let container = try SwiftDataStack.makeContainer()
            let context = ModelContext(container)
            let wallets = try context.fetch(FetchDescriptor<Wallet>())
            guard let wallet = wallets.first(where: { $0.isPrimary }) ?? wallets.first else {
                return SuiWidgetEntry(configuration: configuration)
            }

            let walletId = wallet.id
            let descriptor = FetchDescriptor<CachedPortfolio>(
                predicate: #Predicate { $0.walletId == walletId }
            )
            let portfolio = try context.fetch(descriptor).first

            // Build summaries from the cached portfolio (if any).
            let walletSummary = WalletSummary(
                label: wallet.label ?? wallet.suiNSName ?? Self.shortAddress(wallet.address),
                shortAddress: Self.shortAddress(wallet.address)
            )

            let portfolioSummary = portfolio.map { p -> PortfolioSummary in
                let topHoldings = p.tokens
                    .filter(\.isTracked)
                    .sorted { ($0.priceUSD ?? 0) * $0.balance > ($1.priceUSD ?? 0) * $1.balance }
                    .prefix(3)
                    .map { h in
                        HoldingSummary(
                            symbol: h.symbol,
                            balance: h.balance,
                            usdValue: (h.priceUSD ?? 0) * h.balance,
                            change24h: h.priceChange24h ?? 0
                        )
                    }
                return PortfolioSummary(
                    totalUSD: p.totalUSD,
                    change24hUSD: p.change24hUSD,
                    change24hPercent: p.change24hPercent,
                    topHoldings: Array(topHoldings)
                )
            }

            let stakeSummary = portfolio.map { p -> StakeSummary in
                let totalSUI = p.stakes.reduce(Decimal(0)) { $0 + ($1.principal / Decimal(1_000_000_000)) }
                return StakeSummary(
                    totalSUI: totalSUI,
                    positionCount: p.stakes.count,
                    weightedAPY: nil
                )
            }

            let topNFTs = portfolio?.nfts.filter(\.showInWidget).prefix(4).map { NFTSummary(objectId: $0.objectId, name: $0.name) } ?? []

            let newsDescriptor = FetchDescriptor<CachedNewsItem>(
                sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
            )
            let newsRows = (try? context.fetch(newsDescriptor)) ?? []
            let topNews = newsRows.prefix(3).map {
                NewsSummary(title: $0.title, source: $0.source, publishedAt: $0.publishedAt)
            }

            let snapshotAt = portfolio?.snapshotAt ?? .distantPast
            let isStale = Date().timeIntervalSince(snapshotAt) > 15 * 60

            return SuiWidgetEntry(
                configuration: configuration,
                wallet: walletSummary,
                portfolio: portfolioSummary,
                stakes: stakeSummary,
                topNFTs: Array(topNFTs),
                topNews: Array(topNews),
                isStale: isStale
            )
        } catch {
            return SuiWidgetEntry(configuration: configuration)
        }
    }

    private static func shortAddress(_ address: String) -> String {
        let trimmed = address.hasPrefix("0x") ? String(address.dropFirst(2)) : address
        guard trimmed.count > 8 else { return address }
        let head = trimmed.prefix(4)
        let tail = trimmed.suffix(4)
        return "0x\(head)…\(tail)"
    }
}
