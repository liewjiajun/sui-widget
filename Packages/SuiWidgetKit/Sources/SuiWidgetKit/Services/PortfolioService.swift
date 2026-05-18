import Foundation
import SwiftData

/// Phase 1 integration entry point: builds a `CachedPortfolio` snapshot from
/// on-chain balances + CoinGecko prices. Cache replacement is destructive — the
/// previous snapshot for the wallet is deleted (cascade-clearing children)
/// before the new one is inserted.
public struct PortfolioService {
    public let modelContext: ModelContext
    public let sui: SuiRPCClient
    public let coinGecko: CoinGeckoClient

    public init(
        modelContext: ModelContext,
        sui: SuiRPCClient = SuiRPCClient(),
        coinGecko: CoinGeckoClient
    ) {
        self.modelContext = modelContext
        self.sui = sui
        self.coinGecko = coinGecko
    }

    /// Tokens + prices only. Stakes / NFTs are refreshed by their own services.
    @discardableResult
    public func refresh(walletId: UUID) async throws -> CachedPortfolio {
        let wallet = try fetchWallet(id: walletId)
        guard let owner = SuiAddress(rawValue: wallet.address) else {
            throw SuiNSError.invalidAddress(wallet.address)
        }

        // 1. On-chain balances.
        let balances = try await sui.getAllBalances(owner: owner)

        // 2. Coin-type → CoinGecko-id mapping (24h TTL cache).
        let mappings = try await coinGecko.refreshCoinList(force: false)
        let mappingByCoinType: [String: CoinTypeMapping] = Dictionary(
            uniqueKeysWithValues: mappings.map { ($0.coinType, $0) }
        )

        // 3. Tracked CoinGecko ids.
        var trackedIds: [String] = []
        for balance in balances {
            if let mapping = mappingByCoinType[balance.coinType] {
                trackedIds.append(mapping.coingeckoId)
            }
        }

        // 4. Batch prices.
        let prices: [CoinGeckoMarket]
        if trackedIds.isEmpty {
            prices = []
        } else {
            prices = try await coinGecko.fetchPrices(coingeckoIds: trackedIds)
        }
        let priceById: [String: CoinGeckoMarket] = Dictionary(
            uniqueKeysWithValues: prices.map { ($0.id, $0) }
        )

        // 5. Build CachedTokenHolding rows + totals.
        var portfolioToday: Decimal = 0
        var portfolioYesterday: Decimal = 0
        var holdings: [CachedTokenHolding] = []

        for balance in balances {
            let decimals = decimalsFor(coinType: balance.coinType)
            let unit = pow(10.0, Double(decimals))
            let amountDouble = NSDecimalNumber(decimal: balance.totalBalance).doubleValue / unit
            let amount = Decimal(amountDouble)

            if let mapping = mappingByCoinType[balance.coinType] {
                let market = priceById[mapping.coingeckoId]
                let priceUSD = market?.currentPrice
                let change24h = market?.priceChangePercentage24h

                if let priceUSD {
                    portfolioToday += amount * priceUSD
                    if let change24h {
                        let factor = Decimal(1 + change24h / 100)
                        if factor != 0 {
                            let yesterdayPrice = priceUSD / factor
                            portfolioYesterday += amount * yesterdayPrice
                        } else {
                            portfolioYesterday += amount * priceUSD
                        }
                    } else {
                        portfolioYesterday += amount * priceUSD
                    }
                }

                holdings.append(CachedTokenHolding(
                    coinType: balance.coinType,
                    symbol: mapping.symbol.uppercased(),
                    name: mapping.name,
                    balance: amount,
                    decimals: decimals,
                    priceUSD: priceUSD,
                    priceChange24h: change24h,
                    iconURL: market?.image,
                    isTracked: true
                ))
            } else {
                holdings.append(CachedTokenHolding(
                    coinType: balance.coinType,
                    symbol: shortSymbol(from: balance.coinType),
                    name: balance.coinType,
                    balance: amount,
                    decimals: decimals,
                    priceUSD: nil,
                    priceChange24h: nil,
                    iconURL: nil,
                    isTracked: false
                ))
            }
        }

        // 24h change.
        let change24hUSD = portfolioToday - portfolioYesterday
        let change24hPercent: Double
        if portfolioYesterday != 0 {
            let percentDecimal = (change24hUSD / portfolioYesterday) * 100
            change24hPercent = NSDecimalNumber(decimal: percentDecimal).doubleValue
        } else {
            change24hPercent = 0
        }

        // 6. Cache-replacement.
        if let existing = try fetchPortfolio(walletId: walletId) {
            modelContext.delete(existing)
        }
        let snapshot = CachedPortfolio(
            walletId: walletId,
            totalUSD: portfolioToday,
            change24hUSD: change24hUSD,
            change24hPercent: change24hPercent,
            snapshotAt: Date(),
            tokens: holdings,
            stakes: [],
            nfts: []
        )
        modelContext.insert(snapshot)
        try modelContext.save()
        return snapshot
    }

    /// Convenience: full refresh including stakes + NFTs via their services.
    /// Stakes and NFTs are best-effort — failures there do not roll back the
    /// portfolio snapshot.
    public func refreshAll(walletId: UUID) async throws -> CachedPortfolio {
        let portfolio = try await refresh(walletId: walletId)
        let staking = StakingService(modelContext: modelContext, sui: sui)
        let nfts = NFTService(modelContext: modelContext, sui: sui)
        _ = try? await staking.refresh(walletId: walletId)
        _ = try? await nfts.refresh(walletId: walletId)
        try modelContext.save()
        return try fetchPortfolio(walletId: walletId) ?? portfolio
    }

    // MARK: - Helpers

    private func fetchWallet(id: UUID) throws -> Wallet {
        var descriptor = FetchDescriptor<Wallet>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let wallet = try modelContext.fetch(descriptor).first else {
            throw NSError(
                domain: "PortfolioService", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Wallet not found"]
            )
        }
        return wallet
    }

    private func fetchPortfolio(walletId: UUID) throws -> CachedPortfolio? {
        var descriptor = FetchDescriptor<CachedPortfolio>(predicate: #Predicate { $0.walletId == walletId })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func decimalsFor(coinType: String) -> Int {
        // SUI and most Sui tokens use 9 decimals. Untracked coins may vary; a
        // Phase 2 refinement is to call suix_getCoinMetadata once per coin type.
        return 9
    }

    private func shortSymbol(from coinType: String) -> String {
        // "0x2::sui::SUI" → "SUI"
        let parts = coinType.split(separator: ":")
        return parts.last.map(String.init)?.uppercased() ?? "?"
    }
}
