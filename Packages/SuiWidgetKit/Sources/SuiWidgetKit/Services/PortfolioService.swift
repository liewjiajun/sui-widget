import Foundation
import SwiftData

/// Builds a `CachedPortfolio` snapshot from on-chain balances + CoinGecko
/// prices. Cache replacement is destructive — the previous snapshot for the
/// wallet is deleted (cascade-clearing children) before the new one is inserted.
public struct PortfolioService {
    public let modelContext: ModelContext
    public let sui: SuiRPCClient
    public let coinGecko: CoinGeckoClient
    /// Primary price source — keyed directly by Sui coin type, no API key, far
    /// higher rate limits than CoinGecko's free tier. CoinGecko stays as a
    /// fallback for coins DeFiLlama doesn't track.
    public let deFiLlama: DeFiLlamaClient

    public init(
        modelContext: ModelContext,
        sui: SuiRPCClient = SuiRPCClient(),
        coinGecko: CoinGeckoClient,
        deFiLlama: DeFiLlamaClient = DeFiLlamaClient()
    ) {
        self.modelContext = modelContext
        self.sui = sui
        self.coinGecko = coinGecko
        self.deFiLlama = deFiLlama
    }

    /// A price resolved for one canonical coin type, regardless of source.
    private struct ResolvedPrice {
        var priceUSD: Decimal
        var change24h: Double?
        var symbol: String?
        var name: String?
        var iconURL: String?
        /// The coin's own on-chain decimals when the source reported them.
        var decimals: Int?
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

        // 2. Resolve a USD price for every coin type we care about — every held
        //    balance, plus the underlying asset of any recognised DeFi wrapper
        //    (LST / lending / Kai yToken receipts are valued via their
        //    underlying), plus SUI when the user has stakes. DeFiLlama is the
        //    primary source (keyed by coin type, no key, generous limits) with
        //    CoinGecko as fallback — this is what fixes the CoinGecko 429s.
        let suiCanonical = CoinTypeCanonicalizer.canonicalize("0x2::sui::SUI")
        var typesToPrice: Set<String> = Set(balances.map { CoinTypeCanonicalizer.canonicalize($0.coinType) })
        for balance in balances {
            if let enriched = KnownProtocols.enrichment(forCoinType: balance.coinType) {
                typesToPrice.insert(enriched.underlyingCanonicalCoinType)
            }
        }
        if stakedSUI > 0 { typesToPrice.insert(suiCanonical) }
        let resolved = await resolvePrices(canonicalTypes: Array(typesToPrice))

        // 3. Build CachedTokenHolding rows + totals.
        var portfolioToday: Decimal = 0
        var portfolioYesterday: Decimal = 0
        var holdings: [CachedTokenHolding] = []

        for balance in balances {
            let canonicalCoinType = CoinTypeCanonicalizer.canonicalize(balance.coinType)
            let enrichment = KnownProtocols.enrichment(forCoinType: balance.coinType)

            // Price the wrapper directly when possible; otherwise via its
            // underlying asset (LST / lending / Kai yToken). Decimals always come
            // from the wrapper's OWN source — never the underlying's — so the
            // base-unit conversion stays correct even when prices are borrowed.
            let ownPrice = resolved[canonicalCoinType]
            let priceForValue = ownPrice
                ?? enrichment.flatMap { resolved[$0.underlyingCanonicalCoinType] }

            if let priceForValue {
                // Decimals priority (no `await` right of `??`, so do it stepwise):
                //   1. the price source's reported decimals (DeFiLlama gives these);
                //   2. the registry's live-verified decimals — robust when no source
                //      prices the receipt directly (every Kai yToken), so we never
                //      hit a metadata RPC for a registry coin;
                //   3. a `getCoinMetadata` lookup as a last resort.
                // Without step 2, a rate-limited RPC defaulted to 9 and a 6-decimal
                // yToken's amount (and its USD value) came out 1000x too small.
                let decimals: Int
                if let sourceDecimals = ownPrice?.decimals {
                    decimals = sourceDecimals
                } else if let knownDecimals = enrichment?.decimals {
                    decimals = knownDecimals
                } else {
                    decimals = await ensureDecimals(canonical: canonicalCoinType, rawCoinType: balance.coinType)
                }
                // Pure-Decimal base-unit conversion (exact in base-10; no float drift).
                let amount = balance.totalBalance / pow(Decimal(10), decimals)

                let priceUSD = priceForValue.priceUSD
                let change24h = priceForValue.change24h

                portfolioToday += amount * priceUSD
                if let change24h {
                    let factor = Decimal(1 + change24h / 100)
                    // Guard on sign, not just zero: a thin/erroneous feed can
                    // report change < -100%, making factor negative — dividing by
                    // it would flip the sign and corrupt the snapshot delta. Treat
                    // any change ≤ -100% as degenerate → use today's price.
                    if factor > 0 {
                        portfolioYesterday += amount * (priceUSD / factor)
                    } else {
                        portfolioYesterday += amount * priceUSD
                    }
                } else {
                    portfolioYesterday += amount * priceUSD
                }

                // Symbol/name preference: KnownProtocols override (e.g. "afSUI",
                // "ySUI", "sUSDC") wins so the row reads as the wrapped position;
                // else the price source's own symbol; else on-chain fallback.
                let symbol: String
                let displayName: String
                if let enrichment {
                    symbol = nonEmpty(enrichment.symbolOverride)
                        ?? nonEmpty(ownPrice?.symbol)?.uppercased()
                        ?? shortSymbol(from: balance.coinType)
                    let underlyingName = nonEmpty(priceForValue.name) ?? nonEmpty(priceForValue.symbol) ?? "position"
                    displayName = "\(enrichment.dappName) · \(underlyingName)"
                } else {
                    symbol = nonEmpty(ownPrice?.symbol)?.uppercased() ?? shortSymbol(from: balance.coinType)
                    displayName = nonEmpty(ownPrice?.name) ?? nonEmpty(ownPrice?.symbol) ?? symbol
                }

                holdings.append(CachedTokenHolding(
                    coinType: balance.coinType,
                    symbol: symbol,
                    name: displayName,
                    balance: amount,
                    decimals: decimals,
                    priceUSD: priceUSD,
                    priceChange24h: change24h,
                    iconURL: ownPrice?.iconURL,
                    isTracked: true,
                    dappName: enrichment?.dappName,
                    underlyingCoinType: enrichment?.underlyingCanonicalCoinType,
                    defiCategory: enrichment?.category.rawValue
                ))
            } else {
                // Untracked token — neither source priced it. Surface real
                // symbol / name / decimals via on-chain Move metadata; fall back
                // to a coin-type short-symbol when the RPC fails.
                let metadata = try? await sui.getCoinMetadata(coinType: balance.coinType)
                // Registry decimals first (verified, no RPC), then metadata, then 9.
                let decimals = enrichment?.decimals ?? metadata?.decimals ?? 9
                let amount = balance.totalBalance / pow(Decimal(10), decimals)

                let symbol = nonEmpty(enrichment?.symbolOverride)
                    ?? nonEmpty(metadata?.symbol)
                    ?? shortSymbol(from: balance.coinType)
                let name = enrichment.map { "\($0.dappName) wrapped position" }
                    ?? nonEmpty(metadata?.name)
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

        // 3b. Fold staked SUI value into the portfolio total. Donut slices
        //     still reflect only spendable holdings — the StakedBadge below
        //     the donut surfaces the staked amount as a separate line so the
        //     allocation breakdown remains coherent.
        if stakedSUI > 0, let sui = resolved[suiCanonical] {
            let suiPrice = sui.priceUSD
            let stakedTodayUSD = stakedSUI * suiPrice
            portfolioToday += stakedTodayUSD
            if let change24h = sui.change24h {
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

    /// Trims a string and returns nil if empty, so `??` chains skip blank
    /// symbols/names. Some Sui coins report an empty `symbol` in their metadata;
    /// without this the empty string (being non-nil) would win the `??` and
    /// render a blank token row.
    private func nonEmpty(_ s: String?) -> String? {
        guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }

    /// Best-effort symbol derived purely from the coin type, used only when no
    /// price source and no metadata yielded one. `0x2::sui::SUI` → "SUI". For
    /// Wormhole-style `0x…::coin::COIN` types — where the struct ("COIN") and
    /// module ("coin") are both generic and every bridged asset would collapse
    /// to the same "COIN" — fall back to a short address tag so distinct tokens
    /// stay distinguishable instead of all showing "COIN".
    private func shortSymbol(from coinType: String) -> String {
        let segments = coinType.split(separator: ":").map(String.init).filter { !$0.isEmpty }
        guard let structName = segments.last else { return "?" }
        let module = segments.count >= 2 ? segments[segments.count - 2] : ""
        let generic: Set<String> = ["coin", "COIN"]
        if generic.contains(structName), generic.contains(module) {
            // e.g. 0xaf8cd5…::coin::COIN → "0xaf8c…COIN"
            let addr = segments.first ?? ""
            let head = addr.hasPrefix("0x") ? String(addr.dropFirst(2).prefix(4)) : String(addr.prefix(4))
            return "0x\(head)…COIN"
        }
        return structName.uppercased()
    }

    /// Resolves USD prices for the given canonical coin types, keyed by canonical
    /// coin type. **DeFiLlama is primary** (keyed by coin type, no API key, ~500
    /// req/min, covers Sui long-tail) — this is what fixes the CoinGecko 429
    /// rate-limit problem. **CoinGecko is the fallback** only for coin types
    /// DeFiLlama didn't return. Never throws — a price-source outage degrades to
    /// "untracked" rows rather than failing the whole snapshot.
    private func resolvePrices(canonicalTypes: [String]) async -> [String: ResolvedPrice] {
        var result: [String: ResolvedPrice] = [:]
        guard !canonicalTypes.isEmpty else { return result }

        // 1. DeFiLlama primary (best-effort; keyed directly by Sui coin type).
        if let llama = try? await deFiLlama.fetchPrices(coinTypes: canonicalTypes) {
            for (coinType, price) in llama {
                result[coinType] = ResolvedPrice(
                    priceUSD: price.priceUSD,
                    change24h: price.change24h,
                    symbol: price.symbol,
                    name: price.symbol,   // DeFiLlama only exposes symbol
                    iconURL: nil,
                    decimals: price.decimals
                )
            }
        }

        // 2. CoinGecko fallback for whatever DeFiLlama missed.
        let missing = canonicalTypes.filter { result[$0] == nil }
        guard !missing.isEmpty,
              let mappings = try? await coinGecko.refreshCoinList(force: false)
        else { return result }

        let mappingByCanonical: [String: CoinTypeMapping] = Dictionary(
            mappings.map { (CoinTypeCanonicalizer.canonicalize($0.coinType), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var coingeckoIdForCanonical: [String: String] = [:]
        for coinType in missing {
            if let mapping = mappingByCanonical[coinType] {
                coingeckoIdForCanonical[coinType] = mapping.coingeckoId
            }
        }
        let ids = Array(Set(coingeckoIdForCanonical.values))
        guard !ids.isEmpty,
              let markets = try? await coinGecko.fetchPrices(coingeckoIds: ids)
        else { return result }

        let marketById = Dictionary(markets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for (coinType, id) in coingeckoIdForCanonical {
            guard let market = marketById[id], let price = market.currentPrice else { continue }
            let mapping = mappingByCanonical[coinType]
            result[coinType] = ResolvedPrice(
                priceUSD: price,
                change24h: market.priceChangePercentage24h,
                symbol: mapping?.symbol ?? market.symbol,
                name: mapping?.name,
                iconURL: market.image,
                decimals: nil
            )
        }
        return result
    }
}
