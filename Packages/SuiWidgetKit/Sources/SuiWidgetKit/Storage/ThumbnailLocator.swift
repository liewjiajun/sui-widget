import Foundation

/// Resolves a stored thumbnail reference to a usable on-disk file URL.
///
/// `CachedNFTItem.thumbnailFilePath` stores only the bare filename (e.g.
/// `<hash>.jpg`), NOT an absolute path: the App Group container's absolute path
/// is not guaranteed stable across launches / OS updates, so a persisted
/// absolute path can dangle and the thumbnail silently disappears. We resolve
/// the filename against the *current* container's `Thumbnails/` directory at
/// read time instead.
///
/// For backward compatibility, a reference that is already an absolute path is
/// honored if the file exists there; otherwise we re-resolve its last path
/// component against the current container.
public enum ThumbnailLocator {
    public static let subdirectory = "Thumbnails"

    /// Current App Group `Thumbnails/` directory, or nil outside an entitled target.
    public static func thumbnailsDirectory() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroupStore.groupIdentifier)?
            .appendingPathComponent(subdirectory, isDirectory: true)
    }

    /// Resolves a stored reference (filename or legacy absolute path) to a file
    /// URL that currently exists on disk, or nil when none is found.
    public static func fileURL(forStoredReference reference: String?) -> URL? {
        guard let reference, !reference.isEmpty else { return nil }

        // Legacy absolute path that still exists — use as-is.
        if reference.hasPrefix("/"), FileManager.default.fileExists(atPath: reference) {
            return URL(fileURLWithPath: reference)
        }

        // Resolve the bare filename against the current container.
        let filename = (reference as NSString).lastPathComponent
        guard let dir = thumbnailsDirectory() else { return nil }
        let candidate = dir.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }
}
