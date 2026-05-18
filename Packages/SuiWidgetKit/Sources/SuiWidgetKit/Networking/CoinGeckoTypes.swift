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
    public let currentPrice: Decimal
    public let priceChangePercentage24h: Double?
    public let image: String?

    enum CodingKeys: String, CodingKey {
        case id, symbol
        case currentPrice = "current_price"
        case priceChangePercentage24h = "price_change_percentage_24h"
        case image
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        symbol = try c.decode(String.self, forKey: .symbol)
        // current_price returns a number (Double or Int). Decode as Double then convert.
        let raw = try c.decode(Double.self, forKey: .currentPrice)
        currentPrice = Decimal(raw)
        priceChangePercentage24h = try c.decodeIfPresent(Double.self, forKey: .priceChangePercentage24h)
        image = try c.decodeIfPresent(String.self, forKey: .image)
    }
}
