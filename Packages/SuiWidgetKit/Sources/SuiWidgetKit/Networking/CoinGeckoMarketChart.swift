import Foundation

/// CoinGecko `/coins/{id}/market_chart` response shape.
public struct CoinGeckoMarketChart: Decodable, Equatable, Sendable {
    /// (timestamp_ms, price) pairs sorted oldest-to-newest.
    public let prices: [PricePoint]

    public struct PricePoint: Decodable, Equatable, Sendable {
        public let timestamp: Date
        public let price: Decimal

        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            let millis = try container.decode(Double.self)
            let priceDouble = try container.decode(Double.self)
            self.timestamp = Date(timeIntervalSince1970: millis / 1000)
            self.price = Decimal(priceDouble)
        }
    }

    enum CodingKeys: String, CodingKey { case prices }
}
