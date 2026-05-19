import Foundation

/// Registry of known Sui DeFi protocols whose receipts / wrappers a user's
/// `suix_getAllBalances` call surfaces as ordinary coins. Without enrichment
/// these positions appear as untracked tokens with no price, so the portfolio
/// total understates the user's actual holdings — exactly the user's
/// "tokens staked on other dApps" complaint.
///
/// Coverage is deliberately conservative: each entry needs both a stable
/// on-chain coin type and a pricing path (either a direct CoinGecko id or a
/// canonical underlying coin type we can look up via the existing CoinGecko
/// coin-list cache). We use a near-1:1 ratio approximation when an LST does
/// not have a live exchange-rate feed — production hardening can fold in a
/// price oracle later, but the V1 mistake to avoid is leaving the value at
/// zero.
public enum KnownProtocols {

    /// One enriched mapping: tells `PortfolioService` how to price a wrapped
    /// position and what tag to attach to the resulting row.
    public struct EnrichedHolding: Equatable, Sendable {
        public let dappName: String
        public let symbolOverride: String?
        public let underlyingCanonicalCoinType: String
        public init(
            dappName: String,
            symbolOverride: String? = nil,
            underlyingCanonicalCoinType: String
        ) {
            self.dappName = dappName
            self.symbolOverride = symbolOverride
            self.underlyingCanonicalCoinType = underlyingCanonicalCoinType
        }
    }

    /// Canonical SUI coin type — the underlying for every LST in the registry.
    public static let suiCanonical = CoinTypeCanonicalizer.canonicalize("0x2::sui::SUI")

    /// Direct (full-coin-type) mappings. Keys are canonicalised so they match
    /// what `PortfolioService` already does when keying the CoinGecko lookup.
    private static let directRegistry: [String: EnrichedHolding] = {
        let entries: [(String, EnrichedHolding)] = [
            // afSUI — Aftermath Finance liquid staking token.
            (
                "0xf325ce1300e8dac124071d3152c5c5ee6174914f8bc2161e88329cf579246efc::afsui::AFSUI",
                EnrichedHolding(
                    dappName: "Aftermath",
                    symbolOverride: "afSUI",
                    underlyingCanonicalCoinType: suiCanonical
                )
            ),
            // vSUI — Volo Finance liquid staking certificate.
            (
                "0x549e8b69270defbfafd4f94e17ec44cdbdd99820b33bda2278dea3b9a32d3f55::cert::CERT",
                EnrichedHolding(
                    dappName: "Volo",
                    symbolOverride: "vSUI",
                    underlyingCanonicalCoinType: suiCanonical
                )
            ),
            // haSUI — Haedal Protocol liquid staking token.
            (
                "0xbde4ba4c2e274a60ce15c1cfff9e5c42e41654ac8b6d906a57efa4bd3c29f47d::hasui::HASUI",
                EnrichedHolding(
                    dappName: "Haedal",
                    symbolOverride: "haSUI",
                    underlyingCanonicalCoinType: suiCanonical
                )
            ),
        ]
        return Dictionary(uniqueKeysWithValues: entries.map { (CoinTypeCanonicalizer.canonicalize($0.0), $0.1) })
    }()

    /// Scallop Protocol mainnet package. Their sCoin lending receipts wrap an
    /// underlying coin via `<pkg>::reserve::MarketCoin<UNDERLYING>` — we parse
    /// the underlying out and price the position via that asset's CoinGecko
    /// row. The 1:1 ratio is an approximation; sCoin actually accrues
    /// interest over time, but the right V1 answer is "value at underlying
    /// price" rather than "value at zero".
    public static let scallopPackage =
        "0xefe8b36d5b2e43728cc323298626b83177803521d195cfb11e15b910e892fddf"

    /// Looks up an enriched mapping for a given on-chain coin type. The input
    /// is the raw (possibly short-form) coin type from `suix_getAllBalances`;
    /// callers don't need to canonicalise it themselves.
    public static func enrichment(forCoinType raw: String) -> EnrichedHolding? {
        let canonical = CoinTypeCanonicalizer.canonicalize(raw)
        if let direct = directRegistry[canonical] {
            return direct
        }
        if let scallop = scallopSCoin(canonical: canonical) {
            return scallop
        }
        return nil
    }

    private static func scallopSCoin(canonical: String) -> EnrichedHolding? {
        let prefix = scallopPackage + "::reserve::MarketCoin<"
        guard canonical.hasPrefix(prefix), canonical.hasSuffix(">") else {
            return nil
        }
        let underlyingStart = canonical.index(canonical.startIndex, offsetBy: prefix.count)
        let underlyingEnd = canonical.index(before: canonical.endIndex)
        let underlying = String(canonical[underlyingStart..<underlyingEnd])
        let symbolFromTail = underlying
            .split(separator: ":")
            .last
            .map { String($0) }
            .map { "s" + $0.uppercased() }
        return EnrichedHolding(
            dappName: "Scallop",
            symbolOverride: symbolFromTail,
            underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize(underlying)
        )
    }
}
