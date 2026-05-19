import Foundation
import SwiftData

@Model
public final class CachedNFTItem {
    @Attribute(.unique) public var objectId: String
    public var collectionName: String?
    public var name: String
    public var imageURL: String
    public var thumbnailFilePath: String?
    public var showInWidget: Bool
    public var attributes: [String: String]
    /// Owning wallet's 0x-prefixed address. Optional for SwiftData lightweight
    /// migration — old rows backfill to nil and become invisible to the
    /// wallet-scoped query until the next NFT refresh repopulates them.
    /// Query path: NFTGalleryViewModel reads rows directly via this field so
    /// the gallery doesn't depend on a CachedPortfolio row existing for the
    /// wallet (which was the blocker codex's high-severity finding called out).
    public var walletAddress: String?

    public init(
        objectId: String,
        collectionName: String? = nil,
        name: String,
        imageURL: String,
        thumbnailFilePath: String? = nil,
        showInWidget: Bool = false,
        attributes: [String: String] = [:],
        walletAddress: String? = nil
    ) {
        self.objectId = objectId
        self.collectionName = collectionName
        self.name = name
        self.imageURL = imageURL
        self.thumbnailFilePath = thumbnailFilePath
        self.showInWidget = showInWidget
        self.attributes = attributes
        self.walletAddress = walletAddress
    }
}
