import Foundation

public actor ImageCache {
    public let containerURL: URL
    private let thumbnailsDirURL: URL

    public init(containerURL: URL) {
        self.containerURL = containerURL
        self.thumbnailsDirURL = containerURL.appendingPathComponent("Thumbnails", isDirectory: true)
    }

    /// Writes data atomically to `<container>/Thumbnails/<key>.jpg` and returns the file URL.
    @discardableResult
    public func store(_ data: Data, key: String) async throws -> URL {
        try ensureDirectoryExists()
        let url = fileURL(for: key)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ImagePipelineError.writeFailed(detail: String(describing: error))
        }
        return url
    }

    public func url(forKey key: String) async -> URL? {
        let url = fileURL(for: key)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    public func evict(key: String) async throws {
        let url = fileURL(for: key)
        do {
            try FileManager.default.removeItem(at: url)
        } catch let error as NSError
            where error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
            return  // already gone
        }
    }

    public func evictAll() async throws {
        guard FileManager.default.fileExists(atPath: thumbnailsDirURL.path) else { return }
        try FileManager.default.removeItem(at: thumbnailsDirURL)
    }

    private func fileURL(for key: String) -> URL {
        thumbnailsDirURL.appendingPathComponent("\(key).jpg")
    }

    private func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(
            at: thumbnailsDirURL,
            withIntermediateDirectories: true
        )
    }
}
