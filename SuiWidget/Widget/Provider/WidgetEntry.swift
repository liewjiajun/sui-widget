import WidgetKit
import Foundation
import SuiWidgetKit

public struct SuiWidgetEntry: TimelineEntry, Equatable {
    public let date: Date
    public let configuration: SuiWidgetConfigurationIntent
    public let wallet: WalletSummary?
    public let portfolio: PortfolioSummary?
    public let stakes: StakeSummary?
    public let topNFTs: [NFTSummary]
    public let topNews: [NewsSummary]
    public let sparklinePoints: [Decimal]
    public let isStale: Bool

    public init(
        date: Date = Date(),
        configuration: SuiWidgetConfigurationIntent,
        wallet: WalletSummary? = nil,
        portfolio: PortfolioSummary? = nil,
        stakes: StakeSummary? = nil,
        topNFTs: [NFTSummary] = [],
        topNews: [NewsSummary] = [],
        sparklinePoints: [Decimal] = [],
        isStale: Bool = false
    ) {
        self.date = date
        self.configuration = configuration
        self.wallet = wallet
        self.portfolio = portfolio
        self.stakes = stakes
        self.topNFTs = topNFTs
        self.topNews = topNews
        self.sparklinePoints = sparklinePoints
        self.isStale = isStale
    }

    /// Custom Equatable: `configuration` is an AppIntent (SuiWidgetConfigurationIntent)
    /// which doesn't conform to Equatable, so we exclude it from comparison. SwiftUI
    /// uses this to crossfade timeline entries on the same widget instance — the
    /// configuration is fixed per instance anyway.
    public static func == (lhs: SuiWidgetEntry, rhs: SuiWidgetEntry) -> Bool {
        lhs.date == rhs.date
            && lhs.wallet == rhs.wallet
            && lhs.portfolio == rhs.portfolio
            && lhs.stakes == rhs.stakes
            && lhs.topNFTs == rhs.topNFTs
            && lhs.topNews == rhs.topNews
            && lhs.sparklinePoints == rhs.sparklinePoints
            && lhs.isStale == rhs.isStale
    }

    public static var preview: SuiWidgetEntry {
        SuiWidgetEntry(
            configuration: SuiWidgetConfigurationIntent(),
            wallet: WalletSummary(
                label: "validator.sui",
                suiNSName: "validator.sui",
                shortAddress: "0xe6d2…6a8"
            ),
            portfolio: PortfolioSummary(
                totalUSD: 2841.50,
                change24hUSD: 67.20,
                change24hPercent: 2.4,
                topHoldings: [
                    HoldingSummary(symbol: "SUI", balance: 1240.18, usdValue: 1860.27, change24h: 2.4),
                    HoldingSummary(symbol: "USDC", balance: 500.00, usdValue: 500.00, change24h: 0.0),
                    HoldingSummary(symbol: "DEEP", balance: 80000, usdValue: 481.23, change24h: -3.1),
                ]
            ),
            stakes: StakeSummary(totalSUI: 408.20, positionCount: 3, weightedAPY: 4.8),
            topNFTs: [
                NFTSummary(objectId: "0x1", name: "Suins #1240"),
                NFTSummary(objectId: "0x2", name: "Suins #842"),
                NFTSummary(objectId: "0x3", name: "Pixel Frog"),
                NFTSummary(objectId: "0x4", name: "Mysten OG"),
            ],
            topNews: [
                NewsSummary(title: "Sui Foundation announces…", source: .blog, publishedAt: Date(), heroImageURL: nil),
                NewsSummary(title: "v1.50.0 release", source: .githubRelease, publishedAt: Date(), heroImageURL: nil),
            ],
            sparklinePoints: [1.45, 1.48, 1.50, 1.52, 1.51, 1.55, 1.58, 1.60, 1.62, 1.61, 1.65].map { Decimal($0) },
            isStale: false
        )
    }

    public static var placeholder: SuiWidgetEntry {
        SuiWidgetEntry(configuration: SuiWidgetConfigurationIntent())
    }
}

public struct WalletSummary: Sendable, Equatable {
    /// User-supplied label or nil.
    public let label: String?
    /// Resolved SuiNS name (e.g., "validator.sui") or nil.
    public let suiNSName: String?
    /// Truncated address e.g. "0xe6d2…6a8". Always present.
    public let shortAddress: String

    public init(label: String?, suiNSName: String?, shortAddress: String) {
        self.label = label
        self.suiNSName = suiNSName
        self.shortAddress = shortAddress
    }

    /// Returns the string to display per the user's widget configuration choice.
    /// Returns nil for `.hidden` — caller should omit the label line entirely.
    public func displayString(for choice: WalletIdentifierDisplayOption) -> String? {
        switch choice {
        case .hidden:
            return nil
        case .suiNSName:
            return suiNSName ?? shortAddress
        case .atName:
            // "validator.sui" → "@validator"; if no SuiNS name, fall back to short address.
            guard let name = suiNSName, name.hasSuffix(".sui") else { return shortAddress }
            return "@" + String(name.dropLast(".sui".count))
        case .address:
            return shortAddress
        }
    }
}

public struct PortfolioSummary: Sendable, Equatable {
    public let totalUSD: Decimal
    public let change24hUSD: Decimal
    public let change24hPercent: Double
    public let topHoldings: [HoldingSummary]
    public init(totalUSD: Decimal, change24hUSD: Decimal, change24hPercent: Double, topHoldings: [HoldingSummary]) {
        self.totalUSD = totalUSD
        self.change24hUSD = change24hUSD
        self.change24hPercent = change24hPercent
        self.topHoldings = topHoldings
    }
}

public struct HoldingSummary: Sendable, Equatable {
    public let symbol: String
    public let balance: Decimal
    public let usdValue: Decimal
    public let change24h: Double
    public init(symbol: String, balance: Decimal, usdValue: Decimal, change24h: Double) {
        self.symbol = symbol
        self.balance = balance
        self.usdValue = usdValue
        self.change24h = change24h
    }
}

public struct StakeSummary: Sendable, Equatable {
    public let totalSUI: Decimal
    public let positionCount: Int
    public let weightedAPY: Double?
    public init(totalSUI: Decimal, positionCount: Int, weightedAPY: Double?) {
        self.totalSUI = totalSUI
        self.positionCount = positionCount
        self.weightedAPY = weightedAPY
    }
}

public struct NFTSummary: Sendable, Equatable, Identifiable {
    public let objectId: String
    public let name: String
    public var id: String { objectId }
    public init(objectId: String, name: String) {
        self.objectId = objectId
        self.name = name
    }
}

public struct NewsSummary: Sendable, Equatable, Identifiable {
    public let title: String
    public let source: NewsSource
    public let publishedAt: Date
    public let heroImageURL: String?
    public var id: String { title + "\(publishedAt)" }
    public init(title: String, source: NewsSource, publishedAt: Date, heroImageURL: String? = nil) {
        self.title = title
        self.source = source
        self.publishedAt = publishedAt
        self.heroImageURL = heroImageURL
    }
}
