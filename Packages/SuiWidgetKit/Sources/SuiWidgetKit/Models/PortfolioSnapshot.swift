import Foundation
import SwiftData

/// Aggregate per-wallet portfolio snapshot.
@Model
public final class CachedPortfolio {
    @Attribute(.unique) public var walletId: UUID
    public var totalUSD: Decimal
    public var change24hUSD: Decimal
    public var change24hPercent: Double
    public var snapshotAt: Date
    @Relationship(deleteRule: .cascade) public var tokens: [CachedTokenHolding]
    @Relationship(deleteRule: .cascade) public var stakes: [CachedStakePosition]
    @Relationship(deleteRule: .cascade) public var nfts: [CachedNFTItem]

    public init(
        walletId: UUID,
        totalUSD: Decimal = 0,
        change24hUSD: Decimal = 0,
        change24hPercent: Double = 0,
        snapshotAt: Date = Date(),
        tokens: [CachedTokenHolding] = [],
        stakes: [CachedStakePosition] = [],
        nfts: [CachedNFTItem] = []
    ) {
        self.walletId = walletId
        self.totalUSD = totalUSD
        self.change24hUSD = change24hUSD
        self.change24hPercent = change24hPercent
        self.snapshotAt = snapshotAt
        self.tokens = tokens
        self.stakes = stakes
        self.nfts = nfts
    }
}

@Model
public final class CachedTokenHolding {
    @Attribute(.unique) public var id: UUID
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
        id: UUID = UUID(),
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
        self.id = id
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
