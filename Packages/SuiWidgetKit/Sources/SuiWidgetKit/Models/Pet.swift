import Foundation
import SwiftData

/// V2 stub — soul-bound pixel pet NFT. Not active in V1; never instantiated, never registered
/// in SwiftDataStack.schema. Reserved here so the file path is stable for V2.
@Model
public final class Pet {
    @Attribute(.unique) public var objectId: String
    public var walletAddress: String
    public var seed: String                      // keccak256(walletAddress + "::pet::v1")
    public var level: Int
    public var xp: Int
    public var traits: [String: String]
    public var spriteFilePath: String?
    public var hatchedAt: Date

    public init(
        objectId: String,
        walletAddress: String,
        seed: String,
        level: Int = 1,
        xp: Int = 0,
        traits: [String: String] = [:],
        spriteFilePath: String? = nil,
        hatchedAt: Date = Date()
    ) {
        self.objectId = objectId
        self.walletAddress = walletAddress
        self.seed = seed
        self.level = level
        self.xp = xp
        self.traits = traits
        self.spriteFilePath = spriteFilePath
        self.hatchedAt = hatchedAt
    }
}
