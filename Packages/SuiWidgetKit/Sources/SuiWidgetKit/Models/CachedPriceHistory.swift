import Foundation
import SwiftData

/// One row per CoinGecko id storing the last 24h of hourly price points.
/// Built from CoinGecko's /coins/{id}/market_chart endpoint. Used by the
/// widget's PixelSparkline to render a real price trend.
@Model
public final class CachedPriceHistory {
    @Attribute(.unique) public var coingeckoId: String
    /// JSON-encoded array of Decimal price points (most recent last). SwiftData
    /// stores [Decimal] as a transformable; we serialize manually to avoid
    /// migration surprises.
    public var pricesJSON: String
    public var fetchedAt: Date

    public init(coingeckoId: String, pricesJSON: String = "[]", fetchedAt: Date = Date()) {
        self.coingeckoId = coingeckoId
        self.pricesJSON = pricesJSON
        self.fetchedAt = fetchedAt
    }

    public var prices: [Decimal] {
        guard let data = pricesJSON.data(using: .utf8),
              let array = try? JSONDecoder().decode([Decimal].self, from: data) else {
            return []
        }
        return array
    }

    public func setPrices(_ prices: [Decimal]) {
        if let data = try? JSONEncoder().encode(prices), let json = String(data: data, encoding: .utf8) {
            self.pricesJSON = json
        }
    }
}
