import Foundation

/// Single entry in `/coins/list?include_platform=true` filtered to Sui-platform entries.
public struct CoinGeckoListEntry: Decodable, Equatable, Sendable {
    public let id: String
    public let symbol: String
    public let name: String
    public let platforms: [String: String?]

    /// Returns the Sui coin type if this entry has one, else nil.
    public var suiCoinType: String? {
        if let value = platforms["sui"], let nonNil = value, !nonNil.isEmpty {
            return nonNil
        }
        return nil
    }
}

/// Sui-coin-type → CoinGecko-id mapping derived from a `CoinGeckoListEntry`.
/// This is the value `CoinGeckoClient.refreshCoinList` returns.
public struct CoinTypeMapping: Codable, Equatable, Sendable {
    public let coinType: String          // 0x...::module::TYPE
    public let coingeckoId: String       // e.g. "sui"
    public let symbol: String
    public let name: String

    public init(coinType: String, coingeckoId: String, symbol: String, name: String) {
        self.coinType = coinType
        self.coingeckoId = coingeckoId
        self.symbol = symbol
        self.name = name
    }
}

/// Decoded entry from `/coins/markets?vs_currency=usd&ids=...`.
public struct CoinGeckoMarket: Decodable, Equatable, Sendable {
    public let id: String
    public let symbol: String
    /// Optional: CoinGecko returns `current_price: null` for listed-but-unpriced
    /// coins (illiquid, newly listed, temporarily missing). A non-optional decode
    /// would throw for that single element and — because prices are fetched in one
    /// batched `[CoinGeckoMarket]` decode — poison the price for *every* token in
    /// the batch. `PortfolioService` already treats a nil price as
    /// untracked-for-this-cycle, so optional is the safe, consistent shape.
    public let currentPrice: Decimal?
    public let priceChangePercentage24h: Double?
    public let image: String?

    enum CodingKeys: String, CodingKey {
        case id, symbol
        case currentPrice = "current_price"
        case priceChangePercentage24h = "price_change_percentage_24h"
        case image
    }

    public init(id: String, symbol: String, currentPrice: Decimal?, priceChangePercentage24h: Double?, image: String?) {
        self.id = id
        self.symbol = symbol
        self.currentPrice = currentPrice
        self.priceChangePercentage24h = priceChangePercentage24h
        self.image = image
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        symbol = try c.decode(String.self, forKey: .symbol)
        // current_price returns a number (Double/Int) or null. Decode leniently:
        // a null/absent price → nil instead of a thrown DecodingError that would
        // abort the whole batched market array.
        if let raw = try c.decodeIfPresent(Double.self, forKey: .currentPrice) {
            currentPrice = Decimal(raw)
        } else {
            currentPrice = nil
        }
        priceChangePercentage24h = try c.decodeIfPresent(Double.self, forKey: .priceChangePercentage24h)
        image = try c.decodeIfPresent(String.self, forKey: .image)
    }
}
