import Foundation
import SwiftData

/// One row per Sui-tracked CoinGecko coin. Built from `/coins/list?include_platform=true`
/// by filtering to entries with a `platforms.sui` mapping. Refresh time tracked on
/// `AppSettings.lastCoinListFetchedAt` (one timestamp covers all rows).
@Model
public final class CachedCoinListEntry {
    @Attribute(.unique) public var coinType: String   // e.g. "0x2::sui::SUI"
    public var coingeckoId: String                    // e.g. "sui"
    public var symbol: String
    public var name: String

    public init(
        coinType: String,
        coingeckoId: String,
        symbol: String,
        name: String
    ) {
        self.coinType = coinType
        self.coingeckoId = coingeckoId
        self.symbol = symbol
        self.name = name
    }
}
