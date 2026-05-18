import Foundation
import SwiftData

/// A Sui wallet the user is tracking. Registered in `SwiftDataStack.schema`.
@Model
public final class Wallet {
    @Attribute(.unique) public var id: UUID
    public var address: String          // 0x-prefixed, 32 bytes
    public var label: String?
    public var suiNSName: String?
    public var addedAt: Date
    public var isPrimary: Bool
    public var orderIndex: Int
    /// When false, this wallet is excluded from widget aggregates and the
    /// widget timeline provider's primary-pick fallback. Defaults to true so
    /// existing rows survive a lightweight schema migration.
    public var includeInWidget: Bool

    public init(
        id: UUID = UUID(),
        address: String,
        label: String? = nil,
        suiNSName: String? = nil,
        addedAt: Date = Date(),
        isPrimary: Bool = false,
        orderIndex: Int = 0,
        includeInWidget: Bool = true
    ) {
        self.id = id
        self.address = address
        self.label = label
        self.suiNSName = suiNSName
        self.addedAt = addedAt
        self.isPrimary = isPrimary
        self.orderIndex = orderIndex
        self.includeInWidget = includeInWidget
    }
}
