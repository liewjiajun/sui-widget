import Foundation
import SwiftData
import Observation
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

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        let rpc = SuiRPCClient()
        let suiNS = SuiNSResolver(rpc: rpc, modelContext: modelContext)
        self.walletService = WalletService(modelContext: modelContext, suiNS: suiNS)
        self.nftService = NFTService(modelContext: modelContext, sui: rpc, thumbnails: nil)
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
                ? .empty(message: "No NFTs in this wallet yet.")
                : .loaded
        } catch {
            loadState = .error(message: error.localizedDescription, retry: nil)
        }
    }

    func refresh() async {
        loadState = .loading
        do {
            let wallets = try walletService.list()
            if let primary = wallets.first(where: \.isPrimary) ?? wallets.first {
                _ = try await nftService.refresh(walletId: primary.id)
            }
            load()
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
