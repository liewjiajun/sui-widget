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

    /// Tokens + prices, with staked SUI folded into the portfolio total.
    /// Stake/NFT row enumeration is owned by `StakingService` / `NFTService`;
    /// here we only need the aggregate staked principal so the snapshot's
    /// `totalUSD` (the big number above the donut) reflects everything the
    /// user actually owns, not just spendable wallet balances.
    @discardableResult
    public func refresh(walletId: UUID) async throws -> CachedPortfolio {
        let wallet = try fetchWallet(id: walletId)
        guard let owner = SuiAddress(rawValue: wallet.address) else {
            throw SuiNSError.invalidAddress(wallet.address)
        }

        // 1. On-chain balances + stakes. Stakes are best-effort: a failure
        //    here means the snapshot omits staked value (the StakingService
        //    refresh that follows still populates per-position rows). We
        //    don't want a stake-RPC blip to roll back the entire portfolio
        //    refresh.
        let balances = try await sui.getAllBalances(owner: owner)
        let stakeBundles: [SuiDelegatedStake] = (try? await sui.getStakes(owner: owner)) ?? []
        let stakedBaseUnits: Decimal = stakeBundles.flatMap(\.stakes).reduce(Decimal(0)) {
            $0 + $1.principal + ($1.estimatedReward ?? 0)
        }
        let stakedSUI = stakedBaseUnits / Decimal(1_000_000_000)

        // 2. Coin-type → CoinGecko-id mapping (24h TTL cache). Both sides are
        //    canonicalized so short-form RPC coin types (e.g. `0x2::sui::SUI`)
        //    match long-form CoinGecko entries.
        let mappings = try await coinGecko.refreshCoinList(force: false)
        let canonicalLookup: [String: CoinTypeMapping] = Dictionary(
            uniqueKeysWithValues: mappings.map { (CoinTypeCanonicalizer.canonicalize($0.coinType), $0) }
        )

        // 3. Tracked CoinGecko ids. Always include SUI when the user has any
        //    stakes — otherwise a wallet with all SUI delegated (zero in-wallet)
        //    would have no SUI price fetched and staked value couldn't be
        //    valued in USD. Wrapped DeFi positions (LST receipts, Scallop
        //    sCoins) are priced via their underlying asset's CoinGecko id, so
        //    we also queue the underlying for any balance that matches the
        //    KnownProtocols registry.
        var trackedIds: [String] = []
        for balance in balances {
            let canonical = CoinTypeCanonicalizer.canonicalize(balance.coinType)
            if let mapping = canonicalLookup[canonical] {
                trackedIds.append(mapping.coingeckoId)
            } else if let enriched = KnownProtocols.enrichment(forCoinType: balance.coinType),
                      let underlyingMapping = canonicalLookup[enriched.underlyingCanonicalCoinType] {
                trackedIds.append(underlyingMapping.coingeckoId)
            }
        }
        let suiCanonical = CoinTypeCanonicalizer.canonicalize("0x2::sui::SUI")
        let suiMapping = canonicalLookup[suiCanonical]
        if stakedSUI > 0, let suiMapping, !trackedIds.contains(suiMapping.coingeckoId) {
            trackedIds.append(suiMapping.coingeckoId)
        }

        // 4. Batch prices. Dedupe ids — multiple holdings can map to the same
        //    CoinGecko id (e.g. SUI plus an LST priced via SUI), and duplicate
        //    ids waste the query budget and can confuse the response mapping.
        let uniqueTrackedIds = Array(Set(trackedIds))
        let prices: [CoinGeckoMarket]
        if uniqueTrackedIds.isEmpty {
            prices = []
        } else {
            prices = try await coinGecko.fetchPrices(coingeckoIds: uniqueTrackedIds)
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
            let enrichment = KnownProtocols.enrichment(forCoinType: balance.coinType)

            // Pricing path: direct CoinGecko mapping wins; otherwise fall back
            // to the wrapped position's underlying asset. Either way we get a
            // mapping or nil; nil routes to the untracked path below.
            let directMapping = canonicalLookup[canonicalCoinType]
            let mapping = directMapping
                ?? enrichment.flatMap { canonicalLookup[$0.underlyingCanonicalCoinType] }

            if let mapping {
                let decimals = await ensureDecimals(
                    canonical: canonicalCoinType,
                    rawCoinType: balance.coinType
                )
                // Pure-Decimal base-unit conversion. Routing through Double would
                // truncate a u64 balance (up to 20 digits) to ~15-16 significant
                // digits and reintroduce float noise via Decimal(Double); dividing
                // by a Decimal power-of-ten is exact in base-10.
                let amount = balance.totalBalance / pow(Decimal(10), decimals)

                let market = priceById[mapping.coingeckoId]
                // currentPrice is now optional (CoinGecko sends null for unpriced
                // coins); flatten the double-optional so nil routes through the
                // existing "tracked but unpriced" path (contributes 0 to totals).
                let priceUSD = market?.currentPrice ?? nil
                let change24h = market?.priceChangePercentage24h

                if let priceUSD {
                    portfolioToday += amount * priceUSD
                    if let change24h {
                        let factor = Decimal(1 + change24h / 100)
                        // Guard on sign, not just zero: a thin/erroneous feed can
                        // report change < -100%, making factor negative — dividing
                        // by it would flip the sign and corrupt the snapshot delta.
                        // Treat any change ≤ -100% as degenerate → use today's price.
                        if factor > 0 {
                            let yesterdayPrice = priceUSD / factor
                            portfolioYesterday += amount * yesterdayPrice
                        } else {
                            portfolioYesterday += amount * priceUSD
                        }
                    } else {
                        portfolioYesterday += amount * priceUSD
                    }
                }

                // Symbol/name preference: KnownProtocols override (e.g.,
                // "afSUI", "sUSDC") wins so the row reads as the wrapped
                // position rather than the underlying. Falls back to the
                // direct CoinGecko mapping's name/symbol when the wrapper
                // itself is listed by CoinGecko.
                let symbol: String
                let displayName: String
                if let enrichment {
                    symbol = enrichment.symbolOverride ?? mapping.symbol.uppercased()
                    displayName = "\(enrichment.dappName) · \(mapping.name)"
                } else {
                    symbol = mapping.symbol.uppercased()
                    displayName = mapping.name
                }

                holdings.append(CachedTokenHolding(
                    coinType: balance.coinType,
                    symbol: symbol,
                    name: displayName,
                    balance: amount,
                    decimals: decimals,
                    priceUSD: priceUSD,
                    priceChange24h: change24h,
                    iconURL: market?.image,
                    isTracked: true,
                    dappName: enrichment?.dappName,
                    underlyingCoinType: enrichment?.underlyingCanonicalCoinType,
                    defiCategory: enrichment?.category.rawValue
                ))
            } else {
                // Untracked token. Try to surface real symbol/name/decimals
                // via on-chain Move metadata; fall back to a coin-type
                // short-symbol when the RPC fails.
                let metadata = try? await sui.getCoinMetadata(coinType: balance.coinType)
                let decimals = metadata?.decimals ?? 9
                // Pure-Decimal conversion (see tracked path above).
                let amount = balance.totalBalance / pow(Decimal(10), decimals)

                let symbol = enrichment?.symbolOverride
                    ?? metadata?.symbol
                    ?? shortSymbol(from: balance.coinType)
                let name = enrichment.map { "\($0.dappName) wrapped position" }
                    ?? metadata?.name
                    ?? balance.coinType

                holdings.append(CachedTokenHolding(
                    coinType: balance.coinType,
                    symbol: symbol,
                    name: name,
                    balance: amount,
                    decimals: decimals,
                    priceUSD: nil,
                    priceChange24h: nil,
                    iconURL: metadata?.iconUrl,
                    isTracked: false,
                    dappName: enrichment?.dappName,
                    underlyingCoinType: enrichment?.underlyingCanonicalCoinType,
                    defiCategory: enrichment?.category.rawValue
                ))
            }
        }

        // 5b. Fold staked SUI value into the portfolio total. Donut slices
        //     still reflect only spendable holdings — the StakedBadge below
        //     the donut surfaces the staked amount as a separate line so the
        //     allocation breakdown remains coherent.
        if stakedSUI > 0, let suiMapping {
            let suiMarket = priceById[suiMapping.coingeckoId]
            if let suiPrice = suiMarket?.currentPrice ?? nil {
                let stakedTodayUSD = stakedSUI * suiPrice
                portfolioToday += stakedTodayUSD
                if let change24h = suiMarket?.priceChangePercentage24h {
                    let factor = Decimal(1 + change24h / 100)
                    // Sign guard — see the tracked-token block above.
                    if factor > 0 {
                        portfolioYesterday += stakedSUI * (suiPrice / factor)
                    } else {
                        portfolioYesterday += stakedTodayUSD
                    }
                } else {
                    portfolioYesterday += stakedTodayUSD
                }
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
