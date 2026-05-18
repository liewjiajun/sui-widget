import Foundation
import SwiftData

/// V3 hook. Append-only log of wallet-scoped events used for retroactive
/// quest verification. Declared, registered in `SwiftDataStack.schema`,
/// never written in V1.
@Model
public final class ActivityEvent {
    @Attribute(.unique) public var id: UUID
    public var walletAddress: String
    public var eventType: ActivityEventKind
    public var timestamp: Date
    public var metadata: [String: String]

    public init(
        id: UUID = UUID(),
        walletAddress: String,
        eventType: ActivityEventKind,
        timestamp: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.walletAddress = walletAddress
        self.eventType = eventType
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

/// Discriminator for ActivityEvent.eventType. String-backed for cross-version
/// stability in the persistent store.
public enum ActivityEventKind: String, Codable, CaseIterable, Sendable {
    case walletAdded = "wallet_added"
    case walletRemoved = "wallet_removed"
    case portfolioRefreshed = "portfolio_refreshed"
    case nftSynced = "nft_synced"
    case stakeSynced = "stake_synced"
    case newsRefreshed = "news_refreshed"
}
