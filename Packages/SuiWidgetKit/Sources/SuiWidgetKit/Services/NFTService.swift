import Foundation
import SwiftData

/// Paginates a wallet's owned objects, filters to display-bearing NFTs, and
/// upserts `CachedNFTItem` rows by `objectId`. New rows trigger detached
/// thumbnail generation (best-effort) if a `ThumbnailGenerator` is wired in.
public struct NFTService {
    public let modelContext: ModelContext
    public let sui: SuiRPCClient
    public let thumbnails: ThumbnailGenerator?

    public init(
        modelContext: ModelContext,
        sui: SuiRPCClient = SuiRPCClient(),
        thumbnails: ThumbnailGenerator? = nil
    ) {
        self.modelContext = modelContext
        self.sui = sui
        self.thumbnails = thumbnails
    }

    /// Paginates NFT enumeration for a wallet and upserts `CachedNFTItem` rows.
    /// When `thumbnails` is provided, a detached task is spawned per newly
    /// inserted NFT — thumbnail completion is best-effort and does not block
    /// the returned array.
    @discardableResult
    public func refresh(walletId: UUID) async throws -> [CachedNFTItem] {
        let wallet = try fetchWallet(id: walletId)
        guard let owner = SuiAddress(rawValue: wallet.address) else {
            throw SuiNSError.invalidAddress(wallet.address)
        }

        var allObjects: [SuiOwnedObject] = []
        var cursor: String? = nil
        repeat {
            let page = try await sui.getOwnedObjects(owner: owner, limit: 50, cursor: cursor)
            for wrapper in page.data {
                if let obj = wrapper.data {
                    allObjects.append(obj)
                }
            }
            cursor = page.hasNextPage ? page.nextCursor : nil
        } while cursor != nil

        // Filter to display-bearing objects (NFTs typically carry display metadata).
        let displayObjects = allObjects.filter { $0.display?.data != nil }

        // Existing rows for upsert lookup.
        let existing = try modelContext.fetch(FetchDescriptor<CachedNFTItem>())
        let existingByObjectId: [String: CachedNFTItem] = Dictionary(
            uniqueKeysWithValues: existing.map { ($0.objectId, $0) }
        )

        var result: [CachedNFTItem] = []
        var newItems: [(objectId: String, imageURL: String)] = []
        for obj in displayObjects {
            let displayData = obj.display?.data ?? [:]
            let name = displayData["name"] ?? "Untitled"
            let imageURL = displayData["image_url"] ?? ""
            let collection = obj.type

            if let row = existingByObjectId[obj.objectId] {
                row.name = name
                if !imageURL.isEmpty { row.imageURL = imageURL }
                row.collectionName = collection
                result.append(row)
            } else {
                let row = CachedNFTItem(
                    objectId: obj.objectId,
                    collectionName: collection,
                    name: name,
                    imageURL: imageURL,
                    thumbnailFilePath: nil,
                    showInWidget: false,
                    attributes: displayData.filter { $0.key != "name" && $0.key != "image_url" }
                )
                modelContext.insert(row)
                if !imageURL.isEmpty { newItems.append((obj.objectId, imageURL)) }
                result.append(row)
            }
        }
        try modelContext.save()

        // Best-effort background thumbnail generation for new NFTs. The
        // detached task downloads + resizes the image, then hops onto a
        // dedicated `ThumbnailWriteActor` (which owns its own `ModelContext`)
        // to write the resulting file path back to `CachedNFTItem`. The write
        // is best-effort: if the row was deleted in the meantime, the actor
        // silently no-ops.
        if let thumbnails {
            let writeActor = ThumbnailWriteActor(modelContainer: modelContext.container)
            for (objectId, imageURL) in newItems {
                Task.detached(priority: .background) { [thumbnails] in
                    do {
                        let result = try await thumbnails.generate(
                            objectId: objectId,
                            remoteURL: imageURL
                        )
                        try? await writeActor.writeThumbnailPath(
                            objectId: objectId,
                            path: result.widgetURL.path
                        )
                    } catch {
                        // Best-effort — the next NFT refresh will reconcile.
                    }
                }
            }
        }

        return result
    }

    private func fetchWallet(id: UUID) throws -> Wallet {
        var descriptor = FetchDescriptor<Wallet>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let wallet = try modelContext.fetch(descriptor).first else {
            throw NSError(
                domain: "NFTService", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Wallet not found"]
            )
        }
        return wallet
    }
}
