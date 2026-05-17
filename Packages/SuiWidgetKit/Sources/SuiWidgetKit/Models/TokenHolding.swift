import Foundation

/// Plain struct used by view models. The cached/persisted form is `CachedTokenHolding`
/// in `PortfolioSnapshot.swift`.
public struct TokenHolding: Codable, Equatable {
    public var coinType: String
    public var symbol: String
    public var name: String
    public var balance: Decimal
    public var decimals: Int
    public var priceUSD: Decimal?
    public var priceChange24h: Double?
    public var iconURL: String?
    public var isTracked: Bool

    public init(
        coinType: String,
        symbol: String,
        name: String,
        balance: Decimal,
        decimals: Int,
        priceUSD: Decimal? = nil,
        priceChange24h: Double? = nil,
        iconURL: String? = nil,
        isTracked: Bool
    ) {
        self.coinType = coinType
        self.symbol = symbol
        self.name = name
        self.balance = balance
        self.decimals = decimals
        self.priceUSD = priceUSD
        self.priceChange24h = priceChange24h
        self.iconURL = iconURL
        self.isTracked = isTracked
    }
}
