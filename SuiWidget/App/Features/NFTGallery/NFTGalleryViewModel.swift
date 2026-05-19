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
            // Query NFT rows directly by wallet address — independent of
            // CachedPortfolio. Codex's high-severity finding: if portfolio
            // refresh failed but the NFT RPC succeeded, the rows existed but
            // the gallery couldn't see them because it went through the
            // portfolio relationship. The walletAddress-scoped descriptor
            // makes the gallery robust to portfolio refresh failures.
            let walletAddr = primary.address
            let descriptor = FetchDescriptor<CachedNFTItem>(
                predicate: #Predicate { $0.walletAddress == walletAddr }
            )
            var nfts = (try? modelContext.fetch(descriptor)) ?? []
            // Backward-compat: older NFT rows from before the walletAddress
            // field existed have walletAddress == nil. Fall back to reading
            // them via the portfolio relationship so they don't disappear
            // until the next NFT refresh re-tags them.
            if nfts.isEmpty {
                let walletId = primary.id
                let portfolioDescriptor = FetchDescriptor<CachedPortfolio>(
                    predicate: #Predicate { $0.walletId == walletId }
                )
                nfts = (try? modelContext.fetch(portfolioDescriptor).first?.nfts) ?? []
            }
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
    /// first entry.
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
            // Portfolio refresh is best-effort: NFTService now creates a shell
            // CachedPortfolio if one doesn't exist, and the gallery reads rows
            // by walletAddress, so a portfolio-RPC blip no longer blocks NFTs.
            // A portfolio failure is still surfaced as refreshError so the
            // user sees it instead of silent staleness.
            do {
                _ = try await portfolioService.refresh(walletId: primary.id)
            } catch {
                refreshError = "portfolio: \(error.localizedDescription)"
            }
            _ = try await nftService.refresh(walletId: primary.id)
            load()
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
