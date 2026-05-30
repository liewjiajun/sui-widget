import Foundation

/// Registry of known Sui DeFi protocols whose receipts / wrappers a user's
/// `suix_getAllBalances` call surfaces as ordinary coins. Without enrichment
/// these positions appear as untracked tokens with no price, so the portfolio
/// total understates the user's actual holdings — exactly the user's
/// "show where my tokens are staked / lent" requirement.
///
/// Coverage is deliberately conservative: each entry needs both a stable
/// on-chain coin type and a pricing path (either a direct CoinGecko id or a
/// canonical underlying coin type we can look up via the existing CoinGecko
/// coin-list cache). We price LSTs at the underlying asset's price (a near-1:1
/// approximation; an LST actually accrues a small premium over time). The V1
/// mistake to avoid is leaving a real position valued at zero — but we never
/// fabricate a coin type, so anything not in this curated set still shows as an
/// honest "untracked" row rather than a mispriced one.
public enum KnownProtocols {

    /// Broad class of a DeFi position, used to group rows under the "Earning"
    /// section and to label each with a category pill.
    public enum Category: String, Equatable, Sendable {
        case liquidStaking = "Liquid staking"
        case lending = "Lending"

        /// SF Symbol used for the category's glyph in the UI.
        public var systemImage: String {
            switch self {
            case .liquidStaking: return "drop.circle.fill"
            case .lending: return "banknote.fill"
            }
        }
    }

    /// One enriched mapping: tells `PortfolioService` how to price a wrapped
    /// position and what tag + category to attach to the resulting row.
    public struct EnrichedHolding: Equatable, Sendable {
        public let dappName: String
        public let symbolOverride: String?
        public let underlyingCanonicalCoinType: String
        public let category: Category
        public init(
            dappName: String,
            symbolOverride: String? = nil,
            underlyingCanonicalCoinType: String,
            category: Category
        ) {
            self.dappName = dappName
            self.symbolOverride = symbolOverride
            self.underlyingCanonicalCoinType = underlyingCanonicalCoinType
            self.category = category
        }
    }

    /// Canonical SUI coin type — the underlying for every SUI-LST in the registry.
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
                    underlyingCanonicalCoinType: suiCanonical,
                    category: .liquidStaking
                )
            ),
            // vSUI — Volo Finance liquid staking certificate.
            (
                "0x549e8b69270defbfafd4f94e17ec44cdbdd99820b33bda2278dea3b9a32d3f55::cert::CERT",
                EnrichedHolding(
                    dappName: "Volo",
                    symbolOverride: "vSUI",
                    underlyingCanonicalCoinType: suiCanonical,
                    category: .liquidStaking
                )
            ),
            // haSUI — Haedal Protocol liquid staking token.
            (
                "0xbde4ba4c2e274a60ce15c1cfff9e5c42e41654ac8b6d906a57efa4bd3c29f47d::hasui::HASUI",
                EnrichedHolding(
                    dappName: "Haedal",
                    symbolOverride: "haSUI",
                    underlyingCanonicalCoinType: suiCanonical,
                    category: .liquidStaking
                )
            ),
            // stSUI — Alphafi / Stratis liquid staking token.
            (
                "0xd1b72982e40348d069bb1ff701e634c117bb5f741f44dff91e472d3b01461e55::stsui::STSUI",
                EnrichedHolding(
                    dappName: "AlphaFi",
                    symbolOverride: "stSUI",
                    underlyingCanonicalCoinType: suiCanonical,
                    category: .liquidStaking
                )
            ),
            // sSUI — SpringSui (Suilend) liquid staking token.
            (
                "0x83556891f4a0f233ce7b05cfe7f957d4020492a34f5405b2cb9377d060bef4bf::spring_sui::SPRING_SUI",
                EnrichedHolding(
                    dappName: "SpringSui",
                    symbolOverride: "sSUI",
                    underlyingCanonicalCoinType: suiCanonical,
                    category: .liquidStaking
                )
            ),
            // haWAL — Haedal liquid-staked WAL (Walrus).
            (
                "0x8b4d553839b219c3fd47608a0cc3d5fcc572cb25d41b7df3833208586a8d2470::hawal::HAWAL",
                EnrichedHolding(
                    dappName: "Haedal",
                    symbolOverride: "haWAL",
                    underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize(walCoinType),
                    category: .liquidStaking
                )
            ),
        ]
        // Kai Finance Single-Asset-Vault (SAV) yTokens — yield-bearing lending
        // receipts that show up as ordinary coins in `getAllBalances`. Coin types
        // verified live via `suix_getCoinMetadata` on mainnet; each is priced via
        // its underlying asset (a slight under-estimate vs. the accrued exchange
        // rate, but correct to first order and far better than "untracked"). Only
        // yTokens whose underlying coin type is unambiguous are listed; yWBTC /
        // yWHUSDCe were intentionally omitted pending a verified underlying so we
        // never misprice. Leveraged Kai positions are Shared objects (not coins)
        // and are out of scope.
        let kaiEntries: [(String, EnrichedHolding)] = [
            kaiVault("0xb8dc843a816b51992ee10d2ddc6d28aab4f0a1d651cd7289a7897902eb631613::ysui::YSUI", "ySUI", suiCanonical),
            kaiVault("0x7ea359636b36e7c027c2cd71adedaf19be658e1477d9e71368a0b3824a0a27ff::yusdc::YUSDC", "yUSDC", usdcCoinType),
            kaiVault("0x5b2fa5c76309a417ccd14a65f036b8d1ff4e76a143ed878a47fdecfe0b09860e::ydeep::YDEEP", "yDEEP", deepCoinType),
            kaiVault("0xdab19711df7a4eefc633b9426e15d23305c6815eed775247e477599c706ede98::ywal::YWAL", "yWAL", walCoinType),
            kaiVault("0xdd7108db1a209d23d8a25dda78bdca4547b755094305971ed4064dfe5cdfa026::yusdy::YUSDY", "yUSDY", usdyCoinType),
            kaiVault("0x36bc697c1dba827a4bf7fa3bfc9f1b0953fe09b91c4b4c103efa0b086e03d923::ysuiusdt::YSUIUSDT", "ysuiUSDT", suiUSDTCoinType),
            kaiVault("0xfc39a879b5a8772f682f1202cc5a8a3d93654cbb9e716b96bda7e5832af0e0eb::yxbtc::YXBTC", "yXBTC", xbtcCoinType),
            kaiVault("0x3e83d9c798902dbcde72b9ede9fa2997ea43b302f83e4894aa793e6791e95c9f::ylbtc::YLBTC", "yLBTC", lbtcCoinType),
        ]
        let all = entries + kaiEntries
        return Dictionary(uniqueKeysWithValues: all.map { (CoinTypeCanonicalizer.canonicalize($0.0), $0.1) })
    }()

    // Underlying coin types (mainnet) used by the registry above.
    private static let usdcCoinType = "0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC"
    private static let deepCoinType = "0xdeeb7a4662eec9f2f3def03fb937a663dddaa2e215b8078a284d026b7946c270::deep::DEEP"
    private static let walCoinType = "0x356a26eb9e012a68958082340d4c4116e7f55615cf27affcff209cf0ae544f59::wal::WAL"
    private static let usdyCoinType = "0x960b531667636f39e85867775f52f6b1f220a058c4de786905bdf761e06a56bb::usdy::USDY"
    private static let suiUSDTCoinType = "0x375f70cf2ae4c00bf37117d0c85a2c71545e6ee05c4a5c7d282cd66a4504b068::usdt::USDT"
    private static let xbtcCoinType = "0x876a4b7bce8aeaef60464c11f4026903e9afacab79b9b142686158aa86560b50::xbtc::XBTC"
    private static let lbtcCoinType = "0x3e8e9423d80e1774a7ca128fccd8bf5f1f7753be658c5e645929037f7c819040::lbtc::LBTC"

    /// Builds a Kai SAV yToken registry entry (lending category, priced via
    /// `underlying`). `underlying` is canonicalised here so the
    /// `PortfolioService` price lookup matches.
    private static func kaiVault(_ coinType: String, _ symbol: String, _ underlying: String) -> (String, EnrichedHolding) {
        (
            coinType,
            EnrichedHolding(
                dappName: "Kai",
                symbolOverride: symbol,
                underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize(underlying),
                category: .lending
            )
        )
    }

    /// Lending protocols whose receipt coins wrap an underlying asset inside a
    /// generic type parameter (e.g. `<pkg>::reserve::MarketCoin<USDC>`). For each
    /// we parse the underlying out and price the position via that asset's
    /// CoinGecko row. The 1:1 ratio is an approximation; the receipt actually
    /// accrues interest, but the right V1 answer is "value at underlying price"
    /// rather than "value at zero".
    private struct LendingWrapper {
        let dappName: String
        let typeInfix: String      // e.g. "::reserve::MarketCoin<"
        let symbolPrefix: String   // e.g. "s" → sUSDC
        let package: String
    }

    private static let lendingWrappers: [LendingWrapper] = [
        // Scallop Protocol sCoins.
        LendingWrapper(
            dappName: "Scallop",
            typeInfix: "::reserve::MarketCoin<",
            symbolPrefix: "s",
            package: "0xefe8b36d5b2e43728cc323298626b83177803521d195cfb11e15b910e892fddf"
        ),
    ]

    /// Backwards-compatible alias for the Scallop package (referenced by tests).
    public static var scallopPackage: String { lendingWrappers[0].package }

    /// Looks up an enriched mapping for a given on-chain coin type. The input
    /// is the raw (possibly short-form) coin type from `suix_getAllBalances`;
    /// callers don't need to canonicalise it themselves.
    public static func enrichment(forCoinType raw: String) -> EnrichedHolding? {
        let canonical = CoinTypeCanonicalizer.canonicalize(raw)
        if let direct = directRegistry[canonical] {
            return direct
        }
        if let wrapped = lendingEnrichment(canonical: canonical) {
            return wrapped
        }
        return nil
    }

    private static func lendingEnrichment(canonical: String) -> EnrichedHolding? {
        for wrapper in lendingWrappers {
            let prefix = wrapper.package + wrapper.typeInfix
            guard canonical.hasPrefix(prefix), canonical.hasSuffix(">") else { continue }
            let underlyingStart = canonical.index(canonical.startIndex, offsetBy: prefix.count)
            let underlyingEnd = canonical.index(before: canonical.endIndex)
            let underlying = String(canonical[underlyingStart..<underlyingEnd])
            let symbol = underlying
                .split(separator: ":")
                .last
                .map { String($0) }
                .map { wrapper.symbolPrefix + $0.uppercased() }
            return EnrichedHolding(
                dappName: wrapper.dappName,
                symbolOverride: symbol,
                underlyingCanonicalCoinType: CoinTypeCanonicalizer.canonicalize(underlying),
                category: .lending
            )
        }
        return nil
    }
}
