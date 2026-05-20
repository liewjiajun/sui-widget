import Foundation
import SwiftData

/// Paginates a wallet's owned objects, filters to display-bearing NFTs, and
/// upserts `CachedNFTItem` rows by `objectId`. New rows trigger detached
/// thumbnail generation (best-effort) if a `ThumbnailGenerator` is wired in.
///
/// NFT rows are tagged with their owning wallet's address so the gallery can
/// fetch them directly without depending on a `CachedPortfolio` row existing
/// for the wallet — the codex review found that a balance/pricing failure
/// could leave a wallet without a portfolio row, in which case freshly
/// fetched NFTs would be invisible. We still attach to `CachedPortfolio.nfts`
/// as a secondary convenience (creating a shell portfolio if necessary), so
/// the widget timeline provider's existing `portfolio.nfts` read keeps
/// working.
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
        let walletAddress = wallet.address

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

        // Filter to display-bearing objects (NFTs typically carry display
        // metadata). Require a *non-empty* display map — after lenient display
        // decoding an object whose every display value was null/non-string
        // resolves to an empty dictionary, and surfacing those as "Untitled"
        // imageless rows would just be noise in the gallery.
        let displayObjects = allObjects.filter { !($0.display?.data?.isEmpty ?? true) }

        // Existing rows for upsert lookup.
        let existing = try modelContext.fetch(FetchDescriptor<CachedNFTItem>())
        let existingByObjectId: [String: CachedNFTItem] = Dictionary(
            uniqueKeysWithValues: existing.map { ($0.objectId, $0) }
        )

        var result: [CachedNFTItem] = []
        var newItems: [(objectId: String, imageURL: String)] = []
        for obj in displayObjects {
            let displayData = obj.display?.data ?? [:]
            let name = displayData["name"] ?? displayData["title"] ?? "Untitled"
            // Try several common Sui-NFT display-key variants for the image —
            // SuiNS uses image_url, some collections use imageUrl or image,
            // allowlist passes use image_url too.
            let imageURL = displayData["image_url"]
                ?? displayData["imageUrl"]
                ?? displayData["image"]
                ?? displayData["img_url"]
                ?? ""
            let collection = obj.type

            if let row = existingByObjectId[obj.objectId] {
                row.name = name
                if !imageURL.isEmpty { row.imageURL = imageURL }
                row.collectionName = collection
                row.walletAddress = walletAddress
                result.append(row)
            } else {
                let row = CachedNFTItem(
                    objectId: obj.objectId,
                    collectionName: collection,
                    name: name,
                    imageURL: imageURL,
                    thumbnailFilePath: nil,
                    showInWidget: false,
                    attributes: displayData.filter {
                        $0.key != "name" && $0.key != "title"
                            && $0.key != "image_url" && $0.key != "imageUrl"
                            && $0.key != "image" && $0.key != "img_url"
                    },
                    walletAddress: walletAddress
                )
                modelContext.insert(row)
                if !imageURL.isEmpty { newItems.append((obj.objectId, imageURL)) }
                result.append(row)
            }
        }

        // Attach to CachedPortfolio.nfts as a secondary convenience for the
        // widget timeline provider. If no portfolio exists yet we create a
        // shell one so the relationship is reachable from
        // `TimelineProvider.buildEntry`. PortfolioService.refresh will replace
        // it with a fully-populated snapshot on its next pass.
        let id = walletId
        var portfolioDescriptor = FetchDescriptor<CachedPortfolio>(
            predicate: #Predicate { $0.walletId == id }
        )
        portfolioDescriptor.fetchLimit = 1
        let portfolio: CachedPortfolio
        if let existing = try modelContext.fetch(portfolioDescriptor).first {
            portfolio = existing
        } else {
            let shell = CachedPortfolio(walletId: walletId)
            modelContext.insert(shell)
            portfolio = shell
        }
        let newNFTIds = Set(result.map(\.objectId))
        for stale in portfolio.nfts where !newNFTIds.contains(stale.objectId) {
            portfolio.nfts.removeAll(where: { $0.objectId == stale.objectId })
        }
        let attachedIds = Set(portfolio.nfts.map(\.objectId))
        for nft in result where !attachedIds.contains(nft.objectId) {
            portfolio.nfts.append(nft)
        }

        try modelContext.save()

        // Best-effort background thumbnail generation for new NFTs.
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
