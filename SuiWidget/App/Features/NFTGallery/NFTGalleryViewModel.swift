import Foundation
import SwiftData
import Observation
import WidgetKit
import SuiWidgetKit

@MainActor
@Observable
final class NFTGalleryViewModel {
    var loadState: LoadState = .idle
    var collections: [Collection] = []
    var refreshError: String?

    struct Collection: Identifiable {
        let id: String        // collection name (treats nil collectionName as "Uncategorized")
        let name: String
        let nfts: [CachedNFTItem]
        var inWidgetCount: Int { nfts.filter(\.showInWidget).count }
    }

    private let modelContext: ModelContext
    private let walletService: WalletService
    private let nftService: NFTService
    private let portfolioService: PortfolioService

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        let rpc = SuiRPCClient()
        let suiNS = SuiNSResolver(rpc: rpc, modelContext: modelContext)
        self.walletService = WalletService(modelContext: modelContext, suiNS: suiNS)
        // Root the thumbnail cache at the App Group container so generated
        // thumbnails persist where the widget extension can read them.
        let thumbnailContainerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupStore.groupIdentifier
        ) ?? FileManager.default.temporaryDirectory
        self.nftService = NFTService(
            modelContext: modelContext,
            sui: rpc,
            thumbnails: ThumbnailGenerator(
                cache: ImageCache(containerURL: thumbnailContainerURL)
            )
        )
        // NFTs attach onto the wallet's CachedPortfolio row, so a portfolio
        // refresh has to run before the NFT refresh on first entry — otherwise
        // there's no portfolio to attach to and the NFTGallery view stays
        // empty even after a successful RPC pull.
        self.portfolioService = PortfolioService(
            modelContext: modelContext,
            sui: rpc,
            coinGecko: CoinGeckoClient(modelContext: modelContext)
        )
    }

    func load() {
        do {
            let allWallets = try walletService.list()
            guard let primary = allWallets.first(where: \.isPrimary) ?? allWallets.first else {
                loadState = .empty(message: "Add a wallet to see NFTs.")
                collections = []
                return
            }
            let walletId = primary.id
            let descriptor = FetchDescriptor<CachedPortfolio>(
                predicate: #Predicate { $0.walletId == walletId }
            )
            let nfts = (try? modelContext.fetch(descriptor).first?.nfts) ?? []
            let grouped = Dictionary(grouping: nfts) { $0.collectionName ?? "Uncategorized" }
            collections = grouped
                .map { Collection(id: $0.key, name: $0.key, nfts: $0.value) }
                .sorted { $0.name < $1.name }
            loadState = collections.isEmpty
                ? .empty(message: "No NFTs cached yet. Pull to refresh — NFTs locked in Kiosks (marketplaces) aren't enumerated in V1.")
                : .loaded
        } catch {
            loadState = .error(message: error.localizedDescription, retry: nil)
        }
    }

    /// On every tab appear: load from cache, and if cache is empty kick off a
    /// network refresh so the user doesn't have to manually pull-to-refresh on
    /// first entry. This is the path that surfaces NFTs when a wallet has been
    /// added but its initial sync didn't include an NFT pass for any reason.
    func refreshIfEmpty() {
        if collections.isEmpty {
            Task { await refresh() }
        }
    }

    func refresh() async {
        loadState = .loading
        do {
            let wallets = try walletService.list()
            guard let primary = wallets.first(where: \.isPrimary) ?? wallets.first else {
                load()
                return
            }
            // Portfolio refresh runs first because NFTService attaches the
            // upserted CachedNFTItem rows onto `portfolio.nfts`. If the
            // portfolio row is missing the attachment becomes a no-op.
            _ = try? await portfolioService.refresh(walletId: primary.id)
            _ = try await nftService.refresh(walletId: primary.id)
            load()
            // Widgets read the same portfolio.nfts relationship — reload
            // timelines so any showInWidget thumbnails appear immediately.
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            refreshError = error.localizedDescription
            load()
        }
    }

    func toggleInWidget(for collection: Collection) {
        let allCurrentlyInWidget = collection.nfts.allSatisfy(\.showInWidget)
        let newValue = !allCurrentlyInWidget
        for nft in collection.nfts {
            nft.showInWidget = newValue
        }
        try? modelContext.save()
        load()
    }

    func toggleNFTInWidget(_ nft: CachedNFTItem) {
        nft.showInWidget.toggle()
        try? modelContext.save()
        load()
    }
}
