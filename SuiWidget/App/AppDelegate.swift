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

        let operation = Task<Void, Never> {
            do {
                let container = try SwiftDataStack.makeContainer()
                let context = ModelContext(container)
                let walletService = WalletService(
                    modelContext: context,
                    suiNS: SuiNSResolver(rpc: SuiRPCClient(), modelContext: context)
                )
                let portfolioService = PortfolioService(
                    modelContext: context,
                    sui: SuiRPCClient(),
                    coinGecko: CoinGeckoClient(modelContext: context)
                )
                let stakingService = StakingService(modelContext: context, sui: SuiRPCClient())
                let priceHistory = PriceHistoryService(
                    modelContext: context,
                    coinGecko: CoinGeckoClient(modelContext: context)
                )
                let wallets = (try? walletService.list()) ?? []
                for wallet in wallets.filter(\.includeInWidget) {
                    _ = try? await portfolioService.refresh(walletId: wallet.id)
                    _ = try? await stakingService.refresh(walletId: wallet.id)
                }
                await priceHistory.refreshAll()
                WidgetCenter.shared.reloadAllTimelines()
            } catch {
                // best-effort; nothing more to do
            }
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = { operation.cancel() }
    }

    private func handleCleanupTask(task: BGProcessingTask) {
        scheduleNextCleanup()

        let operation = Task<Void, Never> {
            // Evict orphaned NFT thumbnails — files in App Group/Thumbnails not referenced
            // by any CachedNFTItem.thumbnailFilePath.
            do {
                let container = try SwiftDataStack.makeContainer()
                let context = ModelContext(container)
                let referenced: Set<String> = Set(
                    ((try? context.fetch(FetchDescriptor<CachedNFTItem>())) ?? [])
                        .compactMap(\.thumbnailFilePath)
                )

                let groupURL = FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier: AppGroupStore.groupIdentifier
                )?.appendingPathComponent("Thumbnails", isDirectory: true)
                if let groupURL,
                   let files = try? FileManager.default.contentsOfDirectory(at: groupURL, includingPropertiesForKeys: nil) {
                    for file in files where !referenced.contains(file.path) {
                        try? FileManager.default.removeItem(at: file)
                    }
                }
            } catch {}
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = { operation.cancel() }
    }

    private func handleCoinListTask(task: BGAppRefreshTask) {
        scheduleNextCoinList()
        let operation = Task<Void, Never> {
            do {
                let container = try SwiftDataStack.makeContainer()
                let context = ModelContext(container)
                let coinGecko = CoinGeckoClient(modelContext: context)
                _ = try? await coinGecko.refreshCoinList(force: true)
            } catch {}
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { operation.cancel() }
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
