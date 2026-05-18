import Foundation
import SwiftData

/// Cached validator metadata fetched from `suix_getLatestSuiSystemState`. Used by
/// StakingService to enrich CachedStakePosition rows. 6h TTL via `cachedAt`.
@Model
public final class CachedValidatorMetadata {
    @Attribute(.unique) public var validatorAddress: String
    public var name: String
    public var imageURL: String?
    /// Free-form description from on-chain metadata. Trailing underscore avoids
    /// shadowing CustomStringConvertible.description on enclosing types.
    public var validatorDescription: String?
    public var commissionRate: Double
    public var stakingPool: String
    public var cachedAt: Date

    public init(
        validatorAddress: String,
        name: String,
        imageURL: String? = nil,
        validatorDescription: String? = nil,
        commissionRate: Double = 0,
        stakingPool: String,
        cachedAt: Date = Date()
    ) {
        self.validatorAddress = validatorAddress
        self.name = name
        self.imageURL = imageURL
        self.validatorDescription = validatorDescription
        self.commissionRate = commissionRate
        self.stakingPool = stakingPool
        self.cachedAt = cachedAt
    }
}
