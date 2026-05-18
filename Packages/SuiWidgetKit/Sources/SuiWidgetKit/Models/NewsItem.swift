import Foundation
import SwiftData

@Model
public final class CachedNewsItem {
    @Attribute(.unique) public var id: String   // hash of URL
    public var title: String
    public var url: String
    public var publishedAt: Date
    public var source: NewsSource
    public var summary: String?
    public var heroImageURL: String?

    public init(
        id: String,
        title: String,
        url: String,
        publishedAt: Date,
        source: NewsSource,
        summary: String? = nil,
        heroImageURL: String? = nil
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.publishedAt = publishedAt
        self.source = source
        self.summary = summary
        self.heroImageURL = heroImageURL
    }
}
