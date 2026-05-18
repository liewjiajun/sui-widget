import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

public struct ImageResizer: Sendable {
    public init() {}

    /// Memory-efficient downsample via CGImageSourceCreateThumbnailAtIndex.
    /// Encodes to JPEG at quality 0.8 via CGImageDestination.
    /// - Parameter maxPixelDimension: longest side in pixels; the other side scales proportionally.
    public func resize(_ data: Data, maxPixelDimension: CGFloat) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ImagePipelineError.decodeFailed
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension,
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ImagePipelineError.resizeFailed
        }

        let destData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(destData, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ImagePipelineError.resizeFailed
        }
        let destOptions: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.8,
        ]
        CGImageDestinationAddImage(dest, thumb, destOptions as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw ImagePipelineError.resizeFailed
        }
        return destData as Data
    }
}
