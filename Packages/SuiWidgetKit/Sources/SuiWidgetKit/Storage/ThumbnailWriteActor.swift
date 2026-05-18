import Foundation
import SwiftData

/// Owns its own ModelContext so concurrent thumbnail-generation tasks can write
/// back to `CachedNFTItem.thumbnailFilePath` without crossing into a main-context
/// actor. Each detached `Task` calling `writeThumbnailPath(...)` is serialized
/// through the actor's executor, and the actor's `modelContext` is private to
/// that executor, so SwiftData stays thread-confined.
@ModelActor
public actor ThumbnailWriteActor {
    /// Looks up the `CachedNFTItem` row by `objectId` and writes the on-disk
    /// widget-thumbnail path onto it. Silently no-ops if the row no longer
    /// exists (e.g. the user removed the wallet between the refresh and the
    /// thumbnail completion).
    public func writeThumbnailPath(objectId: String, path: String) throws {
        let descriptor = FetchDescriptor<CachedNFTItem>(
            predicate: #Predicate { $0.objectId == objectId }
        )
        guard let row = try modelContext.fetch(descriptor).first else { return }
        row.thumbnailFilePath = path
        try modelContext.save()
    }
}
