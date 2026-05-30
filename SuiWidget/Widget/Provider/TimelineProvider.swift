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
            let allWallets = try context.fetch(FetchDescriptor<Wallet>())
            let eligibleWallets = allWallets.filter(\.includeInWidget)
            guard !eligibleWallets.isEmpty else {
                return SuiWidgetEntry(configuration: configuration)
            }

            // Honor the per-instance wallet scope. `.all` aggregates every
            // widget-eligible wallet; `.primary` (default) uses the single
            // primary wallet (falling back to the first eligible one).
            let aggregate = configuration.walletScope == .all && eligibleWallets.count > 1
            let targetWallets: [Wallet]
            if aggregate {
                targetWallets = eligibleWallets
            } else if let primary = eligibleWallets.first(where: { $0.isPrimary }) ?? eligibleWallets.first {
                targetWallets = [primary]
            } else {
                return SuiWidgetEntry(configuration: configuration)
            }

            let walletIds = Set(targetWallets.map(\.id))
            let portfolios = ((try? context.fetch(FetchDescriptor<CachedPortfolio>())) ?? [])
                .filter { walletIds.contains($0.walletId) }

            // Wallet identity line.
            let walletSummary: WalletSummary
            if aggregate {
                walletSummary = WalletSummary(
                    label: "All wallets",
                    suiNSName: nil,
                    shortAddress: "\(targetWallets.count) wallets"
                )
            } else if let w = targetWallets.first {
                walletSummary = WalletSummary(
                    label: w.label,
                    suiNSName: w.suiNSName,
                    shortAddress: Self.shortAddress(w.address)
                )
            } else {
                walletSummary = WalletSummary(label: nil, suiNSName: nil, shortAddress: "")
            }

            // Portfolio summary: merge tracked holdings across all target
            // portfolios by symbol so the aggregate widget shows combined value.
            let portfolioSummary: PortfolioSummary? = portfolios.isEmpty ? nil : {
                var totalUSD = Decimal(0)
                var totalChangeUSD = Decimal(0)
                var bySymbol: [String: HoldingSummary] = [:]
                for p in portfolios {
                    totalUSD += p.totalUSD
                    totalChangeUSD += p.change24hUSD
                    for h in p.tokens where h.isTracked {
                        let usd = (h.priceUSD ?? 0) * h.balance
                        if let existing = bySymbol[h.symbol] {
                            // Value-weight the merged 24h% rather than keeping only
                            // the first-seen wallet's value, so a staler snapshot
                            // for the same symbol doesn't dictate the delta glyph.
                            let mergedUSD = existing.usdValue + usd
                            let mergedChange = mergedUSD > 0
                                ? ((existing.usdValue * Decimal(existing.change24h) + usd * Decimal(h.priceChange24h ?? 0)) / mergedUSD as NSDecimalNumber).doubleValue
                                : existing.change24h
                            bySymbol[h.symbol] = HoldingSummary(
                                symbol: h.symbol,
                                balance: existing.balance + h.balance,
                                usdValue: mergedUSD,
                                change24h: mergedChange,
                                dappName: existing.dappName ?? h.dappName
                            )
                        } else {
                            bySymbol[h.symbol] = HoldingSummary(
                                symbol: h.symbol,
                                balance: h.balance,
                                usdValue: usd,
                                change24h: h.priceChange24h ?? 0,
                                dappName: h.dappName
                            )
                        }
                    }
                }
                let top = bySymbol.values.sorted { $0.usdValue > $1.usdValue }.prefix(3)
                let yesterday = totalUSD - totalChangeUSD
                let pct: Double = yesterday > 0
                    ? ((totalChangeUSD / yesterday) as NSDecimalNumber).doubleValue * 100
                    : 0
                return PortfolioSummary(
                    totalUSD: totalUSD,
                    change24hUSD: totalChangeUSD,
                    change24hPercent: pct,
                    topHoldings: Array(top)
                )
            }()

            let stakeSummary: StakeSummary? = portfolios.isEmpty ? nil : {
                let allStakes = portfolios.flatMap(\.stakes)
                let totalSUI = allStakes.reduce(Decimal(0)) { $0 + ($1.principal / Decimal(1_000_000_000)) }
                return StakeSummary(totalSUI: totalSUI, positionCount: allStakes.count, weightedAPY: nil)
            }()

            let topNFTs = portfolios.flatMap { $0.nfts.filter(\.showInWidget) }.prefix(4).map {
                NFTSummary(
                    objectId: $0.objectId,
                    name: $0.name,
                    thumbnailFilePath: $0.thumbnailFilePath,
                    imageURL: $0.imageURL.isEmpty ? nil : $0.imageURL
                )
            }

            let newsDescriptor = FetchDescriptor<CachedNewsItem>(
                sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
            )
            let newsRows = (try? context.fetch(newsDescriptor)) ?? []
            let topNews = newsRows.prefix(3).map {
                NewsSummary(
                    title: $0.title,
                    source: $0.source,
                    publishedAt: $0.publishedAt,
                    heroImageURL: $0.heroImageURL
                )
            }

            let snapshotAt = portfolios.map(\.snapshotAt).max() ?? .distantPast
            let isStale = Date().timeIntervalSince(snapshotAt) > 15 * 60

            // Sparkline: top tracked token's cached price history (skipped for
            // aggregate, where a single token's curve isn't meaningful).
            let sparklinePoints: [Decimal] = {
                guard !aggregate,
                      let topTrackedSymbol = portfolioSummary?.topHoldings
                          .first(where: { ($0.usdValue as NSDecimalNumber).doubleValue > 0 })?.symbol
                else { return [] }
                let allMappings = (try? context.fetch(FetchDescriptor<CachedCoinListEntry>())) ?? []
                guard let mapping = allMappings.first(where: { $0.symbol.uppercased() == topTrackedSymbol.uppercased() }) else {
                    return []
                }
                let id = mapping.coingeckoId
                let descriptor = FetchDescriptor<CachedPriceHistory>(predicate: #Predicate { $0.coingeckoId == id })
                return (try? context.fetch(descriptor).first)?.prices ?? []
            }()

            return SuiWidgetEntry(
                configuration: configuration,
                wallet: walletSummary,
                portfolio: portfolioSummary,
                stakes: stakeSummary,
                topNFTs: Array(topNFTs),
                topNews: Array(topNews),
                sparklinePoints: sparklinePoints,
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
