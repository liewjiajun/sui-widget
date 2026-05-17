import Foundation
import SwiftData

@Model
public final class CachedNFTItem {
    public var objectId: String
    public var collectionName: String?
    public var name: String
    public var imageURL: String
    public var thumbnailFilePath: String?
    public var showInWidget: Bool
    public var attributes: [String: String]

    public init(
        objectId: String,
        collectionName: String? = nil,
        name: String,
        imageURL: String,
        thumbnailFilePath: String? = nil,
        showInWidget: Bool = false,
        attributes: [String: String] = [:]
    ) {
        self.objectId = objectId
        self.collectionName = collectionName
        self.name = name
        self.imageURL = imageURL
        self.thumbnailFilePath = thumbnailFilePath
        self.showInWidget = showInWidget
        self.attributes = attributes
    }
}
