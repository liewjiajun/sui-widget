import Foundation
import SwiftData

/// One row per Sui-tracked CoinGecko coin. Built from `/coins/list?include_platform=true`
/// by filtering to entries with a `platforms.sui` mapping. Refresh time tracked on
/// `AppSettings.lastCoinListFetchedAt` (one timestamp covers all rows).
@Model
public final class CachedCoinListEntry {
    @Attribute(.unique) public var coinType: String   // canonicalized form
    public var coingeckoId: String                    // e.g. "sui"
    public var symbol: String
    public var name: String
    /// On-chain decimals from `suix_getCoinMetadata`. Populated lazily by
    /// `PortfolioService.ensureDecimals` on first miss. Defaults to 9 (the SUI
    /// convention) so existing rows survive a lightweight schema migration.
    public var decimals: Int

    public init(
        coinType: String,
        coingeckoId: String,
        symbol: String,
        name: String,
        decimals: Int = 9
    ) {
        self.coinType = coinType
        self.coingeckoId = coingeckoId
        self.symbol = symbol
        self.name = name
        self.decimals = decimals
    }
}
