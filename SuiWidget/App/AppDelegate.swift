import UIKit
import BackgroundTasks
import SwiftData
import WidgetKit
import SuiWidgetKit

/// Hosts BGTaskScheduler registration for:
/// - io.sui.widget.refresh (BGAppRefreshTask — every 30 min by default, follows AppSettings.refreshFrequencyMinutes)
/// - io.sui.widget.cleanup (BGProcessingTask — weekly)
/// - io.sui.widget.coinlist (BGAppRefreshTask — daily)
final class AppDelegate: NSObject, UIApplicationDelegate {
    static let refreshIdentifier = "io.sui.widget.refresh"
    static let cleanupIdentifier = "io.sui.widget.cleanup"
    static let coinListIdentifier = "io.sui.widget.coinlist"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        registerBackgroundTasks()
        scheduleBackgroundTasks()
        return true
    }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshIdentifier, using: nil) { task in
            self.handleRefreshTask(task: task as! BGAppRefreshTask)
        }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.cleanupIdentifier, using: nil) { task in
            self.handleCleanupTask(task: task as! BGProcessingTask)
        }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.coinListIdentifier, using: nil) { task in
            self.handleCoinListTask(task: task as! BGAppRefreshTask)
        }
    }

    func scheduleBackgroundTasks() {
        // Refresh: cadence from AppSettings.refreshFrequencyMinutes (defaults to 30).
        let minutes = currentRefreshMinutes()
        let refreshRequest = BGAppRefreshTaskRequest(identifier: Self.refreshIdentifier)
        refreshRequest.earliestBeginDate = Date(timeIntervalSinceNow: Double(minutes) * 60)
        try? BGTaskScheduler.shared.submit(refreshRequest)

        // Cleanup: weekly.
        let cleanupRequest = BGProcessingTaskRequest(identifier: Self.cleanupIdentifier)
        cleanupRequest.requiresNetworkConnectivity = false
        cleanupRequest.earliestBeginDate = Date(timeIntervalSinceNow: 7 * 24 * 60 * 60)
        try? BGTaskScheduler.shared.submit(cleanupRequest)

        // Coin list: daily.
        let coinListRequest = BGAppRefreshTaskRequest(identifier: Self.coinListIdentifier)
        coinListRequest.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60)
        try? BGTaskScheduler.shared.submit(coinListRequest)
    }

    private func currentRefreshMinutes() -> Int {
        do {
            let container = try SwiftDataStack.makeContainer()
            let context = ModelContext(container)
            if let settings = try context.fetch(FetchDescriptor<AppSettings>()).first {
                return max(15, settings.refreshFrequencyMinutes)
            }
        } catch {
            // fall through
        }
        return 30
    }

    // MARK: - Handlers

    private func handleRefreshTask(task: BGAppRefreshTask) {
        // Always reschedule next instance first so the chain continues.
        scheduleNextRefresh()

        // Install the expiration handler BEFORE starting async work. Assigning it
        // after `Task {…}` leaves a window where the system could suspend the task
        // with no handler installed; we capture the operation lazily so the
        // handler can cancel it.
        let operationBox = TaskBox()
        task.expirationHandler = { operationBox.task?.cancel() }

        let operation = Task<Void, Never> {
            do {
                let container = try SwiftDataStack.makeContainer()
                let context = ModelContext(container)
                let rpc = SuiRPCClient()
                let coinGecko = CoinGeckoClient(modelContext: context)
                let walletService = WalletService(
                    modelContext: context,
                    suiNS: SuiNSResolver(rpc: rpc, modelContext: context)
                )
                let portfolioService = PortfolioService(
                    modelContext: context,
                    sui: rpc,
                    coinGecko: coinGecko
                )
                let stakingService = StakingService(modelContext: context, sui: rpc)
                let priceHistory = PriceHistoryService(
                    modelContext: context,
                    coinGecko: coinGecko
                )
                // NFT refresh writes thumbnails into the App Group so the
                // widget extension can read them without a network round-trip.
                let thumbnailContainerURL = FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier: AppGroupStore.groupIdentifier
                ) ?? FileManager.default.temporaryDirectory
                let nftService = NFTService(
                    modelContext: context,
                    sui: rpc,
                    thumbnails: ThumbnailGenerator(
                        cache: ImageCache(containerURL: thumbnailContainerURL)
                    )
                )
                let newsService = NewsService(modelContext: context, rss: RSSClient())

                let wallets = (try? walletService.list()) ?? []
                for wallet in wallets.filter(\.includeInWidget) {
                    // Strict sequencing within a wallet — portfolio first so
                    // stakes/NFTs attach to the fresh snapshot.
                    _ = try? await portfolioService.refresh(walletId: wallet.id)
                    _ = try? await stakingService.refresh(walletId: wallet.id)
                    _ = try? await nftService.refresh(walletId: wallet.id)
                }
                // News + price history are wallet-independent — refresh once
                // after the per-wallet loop. News is what populates the
                // widget's news rows; without this the widget showed nothing.
                _ = try? await newsService.refresh(force: false)
                await priceHistory.refreshAll()
                await FXRateStore.shared.refreshIfStale(coinGecko: coinGecko)
                WidgetCenter.shared.reloadAllTimelines()
            } catch {
                // best-effort; nothing more to do
            }
            task.setTaskCompleted(success: true)
        }
        operationBox.task = operation
    }

    private func handleCleanupTask(task: BGProcessingTask) {
        scheduleNextCleanup()

        let operationBox = TaskBox()
        task.expirationHandler = { operationBox.task?.cancel() }

        let operation = Task<Void, Never> {
            // Evict orphaned NFT thumbnails — files in App Group/Thumbnails not referenced
            // by any CachedNFTItem.thumbnailFilePath.
            do {
                let container = try SwiftDataStack.makeContainer()
                let context = ModelContext(container)
                // thumbnailFilePath now stores bare filenames (see
                // ThumbnailLocator); compare by lastPathComponent so the
                // orphan sweep matches stored references regardless of whether
                // an old row holds a legacy absolute path.
                let referenced: Set<String> = Set(
                    ((try? context.fetch(FetchDescriptor<CachedNFTItem>())) ?? [])
                        .compactMap(\.thumbnailFilePath)
                        .map { ($0 as NSString).lastPathComponent }
                )

                let groupURL = ThumbnailLocator.thumbnailsDirectory()
                if let groupURL,
                   let files = try? FileManager.default.contentsOfDirectory(at: groupURL, includingPropertiesForKeys: nil) {
                    for file in files where !referenced.contains(file.lastPathComponent) {
                        try? FileManager.default.removeItem(at: file)
                    }
                }
            } catch {}
            task.setTaskCompleted(success: true)
        }
        operationBox.task = operation
    }

    private func handleCoinListTask(task: BGAppRefreshTask) {
        scheduleNextCoinList()

        let operationBox = TaskBox()
        task.expirationHandler = { operationBox.task?.cancel() }

        let operation = Task<Void, Never> {
            do {
                let container = try SwiftDataStack.makeContainer()
                let context = ModelContext(container)
                let coinGecko = CoinGeckoClient(modelContext: context)
                _ = try? await coinGecko.refreshCoinList(force: true)
                // FX rates share the daily coin-list cadence.
                await FXRateStore.shared.refreshIfStale(coinGecko: coinGecko)
            } catch {}
            task.setTaskCompleted(success: true)
        }
        operationBox.task = operation
    }

    private func scheduleNextRefresh() {
        let minutes = currentRefreshMinutes()
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Double(minutes) * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func scheduleNextCleanup() {
        let request = BGProcessingTaskRequest(identifier: Self.cleanupIdentifier)
        request.requiresNetworkConnectivity = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 7 * 24 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func scheduleNextCoinList() {
        let request = BGAppRefreshTaskRequest(identifier: Self.coinListIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}

/// Lets a `BGTask.expirationHandler` (installed before the work `Task` is
/// created) reach back and cancel that `Task` once it exists, closing the race
/// where the system could suspend the task before a handler was installed.
private final class TaskBox: @unchecked Sendable {
    var task: Task<Void, Never>?
}
