import Foundation
import SwiftData

/// Builds a `CachedPortfolio` snapshot from on-chain balances + CoinGecko
/// prices. Cache replacement is destructive — the previous snapshot for the
/// wallet is deleted (cascade-clearing children) before the new one is inserted.
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

        // 2. Coin-type → CoinGecko-id mapping (24h TTL cache). Both sides are
        //    canonicalized so short-form RPC coin types (e.g. `0x2::sui::SUI`)
        //    match long-form CoinGecko entries.
        let mappings = try await coinGecko.refreshCoinList(force: false)
        let canonicalLookup: [String: CoinTypeMapping] = Dictionary(
            uniqueKeysWithValues: mappings.map { (CoinTypeCanonicalizer.canonicalize($0.coinType), $0) }
        )

        // 3. Tracked CoinGecko ids.
        var trackedIds: [String] = []
        for balance in balances {
            let canonical = CoinTypeCanonicalizer.canonicalize(balance.coinType)
            if let mapping = canonicalLookup[canonical] {
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
            let canonicalCoinType = CoinTypeCanonicalizer.canonicalize(balance.coinType)

            if let mapping = canonicalLookup[canonicalCoinType] {
                // Tracked token. Look up cached decimals (lazily populated via
                // suix_getCoinMetadata on first miss).
                let decimals = await ensureDecimals(
                    canonical: canonicalCoinType,
                    rawCoinType: balance.coinType
                )
                let unit = pow(10.0, Double(decimals))
                let amountDouble = NSDecimalNumber(decimal: balance.totalBalance).doubleValue / unit
                let amount = Decimal(amountDouble)

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
                // Untracked token. Try to surface real symbol/name/decimals
                // via on-chain Move metadata; fall back to a coin-type
                // short-symbol when the RPC fails.
                let metadata = try? await sui.getCoinMetadata(coinType: balance.coinType)
                let decimals = metadata?.decimals ?? 9
                let unit = pow(10.0, Double(decimals))
                let amountDouble = NSDecimalNumber(decimal: balance.totalBalance).doubleValue / unit
                let amount = Decimal(amountDouble)

                let symbol = metadata?.symbol ?? shortSymbol(from: balance.coinType)
                let name = metadata?.name ?? balance.coinType

                holdings.append(CachedTokenHolding(
                    coinType: balance.coinType,
                    symbol: symbol,
                    name: name,
                    balance: amount,
                    decimals: decimals,
                    priceUSD: nil,
                    priceChange24h: nil,
                    iconURL: metadata?.iconUrl,
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

    /// Returns decimals for a tracked coin type. Checks the cached
    /// `CachedCoinListEntry.decimals` first; on a miss (or default-9 row that
    /// pre-dates this lookup), fetches `suix_getCoinMetadata` once and persists
    /// the result. Returns 9 (SUI default) if both paths fail.
    private func ensureDecimals(canonical: String, rawCoinType: String) async -> Int {
        let descriptor = FetchDescriptor<CachedCoinListEntry>(
            predicate: #Predicate { $0.coinType == canonical }
        )
        let row = try? modelContext.fetch(descriptor).first
        // First call after migration: every existing row has decimals == 9 by
        // default, so we still want to confirm via metadata. We treat any row
        // we've already enriched (decimals != 9) as authoritative; for the
        // remainder we fall through to a one-shot metadata fetch.
        if let row, row.decimals != 9 {
            return row.decimals
        }
        if let metadata = try? await sui.getCoinMetadata(coinType: rawCoinType) {
            if let row {
                row.decimals = metadata.decimals
                try? modelContext.save()
            }
            return metadata.decimals
        }
        return row?.decimals ?? 9
    }

    private func shortSymbol(from coinType: String) -> String {
        // "0x2::sui::SUI" → "SUI". Fallback used only when getCoinMetadata fails
        // for an untracked coin.
        let parts = coinType.split(separator: ":")
        return parts.last.map(String.init)?.uppercased() ?? "?"
    }
}
