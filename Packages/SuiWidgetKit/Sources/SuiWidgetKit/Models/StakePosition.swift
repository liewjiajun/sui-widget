import Foundation
import SwiftData

@Model
public final class CachedStakePosition {
    public var validatorAddress: String
    public var validatorName: String?
    public var validatorImageURL: String?
    public var principal: Decimal
    public var estimatedReward: Decimal
    public var status: String        // "active", "pending", "withdrawing"
    public var stakingPool: String

    public init(
        validatorAddress: String,
        validatorName: String? = nil,
        validatorImageURL: String? = nil,
        principal: Decimal = 0,
        estimatedReward: Decimal = 0,
        status: String,
        stakingPool: String
    ) {
        self.validatorAddress = validatorAddress
        self.validatorName = validatorName
        self.validatorImageURL = validatorImageURL
        self.principal = principal
        self.estimatedReward = estimatedReward
        self.status = status
        self.stakingPool = stakingPool
    }
}
