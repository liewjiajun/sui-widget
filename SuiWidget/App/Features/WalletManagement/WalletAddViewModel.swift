import Foundation
import SwiftData
import Observation
import WidgetKit
import SuiWidgetKit

enum WalletAddResolution: Equatable {
    case empty
    case resolving
    case resolved(SuiAddress)
    case notFound
    case invalid
    case error(String)
}

@MainActor
@Observable
final class WalletAddViewModel {
    var input: String = "" {
        didSet {
            guard input != oldValue else { return }
            scheduleResolution()
        }
    }
    var label: String = ""
    var setAsPrimary: Bool = false
    var resolution: WalletAddResolution = .empty
    var didAdd: Bool = false
    var addError: String?
    /// True while the post-add initial sync (portfolio + stakes + NFTs + news)
    /// is running. The Add Wallet sheet stays presented and the form is locked
    /// so the user knows the new wallet is being primed before the sheet
    /// dismisses. Without this, the widget would render empty until the next
    /// background refresh.
    var isSyncing: Bool = false

    private let modelContext: ModelContext
    private let walletService: WalletService
    private let suiNS: SuiNSResolver
    private let rpc: SuiRPCClient
    private var resolveTask: Task<Void, Never>?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        let rpc = SuiRPCClient()
        let resolver = SuiNSResolver(rpc: rpc, modelContext: modelContext)
        self.rpc = rpc
        self.suiNS = resolver
        self.walletService = WalletService(modelContext: modelContext, suiNS: resolver)
    }

    private func scheduleResolution() {
        resolveTask?.cancel()
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            resolution = .empty
            return
        }
        // Plain 0x address validates immediately, no debounce.
        if trimmed.hasPrefix("0x") {
            if let addr = SuiAddress(rawValue: trimmed) {
                resolution = .resolved(addr)
            } else {
                resolution = .invalid
            }
            return
        }
        // .sui or @name — debounce 400ms then RPC.
        resolution = .resolving
        resolveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await self?.resolveInput(trimmed)
        }
    }

    private func resolveInput(_ trimmed: String) async {
        do {
            let addr = try await suiNS.resolve(trimmed)
            resolution = .resolved(addr)
        } catch let err as SuiNSError {
            switch err {
            case .nameNotFound: resolution = .notFound
            case .invalidName, .invalidAddress: resolution = .invalid
            case .rpc(let underlying): resolution = .error(underlying.localizedDescription)
            }
        } catch {
            resolution = .error(error.localizedDescription)
        }
    }

    var canAdd: Bool {
        if case .resolved = resolution { return true }
        return false
    }

    func add() async {
        guard canAdd else { return }
        do {
            let wallet = try await walletService.add(
                addressOrName: input.trimmingCharacters(in: .whitespacesAndNewlines),
                label: label.isEmpty ? nil : label
            )
            if setAsPrimary { try walletService.setPrimary(id: wallet.id) }

            // Prime the caches for the new wallet before dismissing the sheet
            // so the widget timeline and Portfolio/NFT/News tabs all have data
            // on first appearance. Failures here are best-effort — the wallet
            // is already persisted; the next foreground/background refresh will
            // reconcile anything that timed out.
            isSyncing = true
            await runInitialSync(walletId: wallet.id)
            isSyncing = false

            // Force widget timelines to recompute now that the App Group store
            // has portfolio/news data for the new wallet.
            WidgetCenter.shared.reloadAllTimelines()

            didAdd = true
            addError = nil
        } catch {
            isSyncing = false
            addError = "Failed to add wallet: \(error.localizedDescription)"
        }
    }

    private func runInitialSync(walletId: UUID) async {
        let coinGecko = CoinGeckoClient(modelContext: modelContext)
        let portfolioService = PortfolioService(
            modelContext: modelContext,
            sui: rpc,
            coinGecko: coinGecko
        )
        let stakingService = StakingService(modelContext: modelContext, sui: rpc)

        // Root the thumbnail cache at the App Group container so generated
        // thumbnails persist where the widget extension can read them.
        let thumbnailContainerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupStore.groupIdentifier
        ) ?? FileManager.default.temporaryDirectory
        let nftService = NFTService(
            modelContext: modelContext,
            sui: rpc,
            thumbnails: ThumbnailGenerator(
                cache: ImageCache(containerURL: thumbnailContainerURL)
            )
        )
        let newsService = NewsService(modelContext: modelContext, rss: RSSClient())

        // Strict sequencing: portfolio must create the CachedPortfolio row
        // before stakes/NFTs attach to it. News is unrelated and runs last.
        _ = try? await portfolioService.refresh(walletId: walletId)
        _ = try? await stakingService.refresh(walletId: walletId)
        _ = try? await nftService.refresh(walletId: walletId)
        _ = try? await newsService.refresh(force: false)
    }
}
