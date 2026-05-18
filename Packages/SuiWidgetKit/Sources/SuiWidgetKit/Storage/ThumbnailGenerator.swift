import Foundation
import CryptoKit

public struct ThumbnailGenerator: Sendable {
    public struct Result: Equatable, Sendable {
        public let widgetURL: URL      // 200×200
        public let galleryURL: URL     // 600×600
    }

    public let downloader: ImageDownloader
    public let resizer: ImageResizer
    public let cache: ImageCache

    /// Widget size for the small-NFT use case.
    public static let widgetSize: CGFloat = 200
    /// Gallery (in-app) size.
    public static let gallerySize: CGFloat = 600

    public init(
        downloader: ImageDownloader = ImageDownloader(),
        resizer: ImageResizer = ImageResizer(),
        cache: ImageCache
    ) {
        self.downloader = downloader
        self.resizer = resizer
        self.cache = cache
    }

    public func generate(objectId: String, remoteURL: String) async throws -> Result {
        let data = try await downloader.download(remoteURL: remoteURL)

        async let widgetData = resizer.resize(data, maxPixelDimension: Self.widgetSize)
        async let galleryData = resizer.resize(data, maxPixelDimension: Self.gallerySize)

        let (wData, gData) = try await (widgetData, galleryData)

        let widgetKey = Self.key(objectId: objectId, size: Self.widgetSize)
        let galleryKey = Self.key(objectId: objectId, size: Self.gallerySize)

        async let widgetURL = cache.store(wData, key: widgetKey)
        async let galleryURL = cache.store(gData, key: galleryKey)

        return try await Result(widgetURL: widgetURL, galleryURL: galleryURL)
    }

    public static func key(objectId: String, size: CGFloat) -> String {
        let input = "\(objectId):\(Int(size))"
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
