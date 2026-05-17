import UIKit

/// Placeholder. Phase 1 will host BGTaskScheduler registration for:
/// - io.sui.widget.refresh (BGAppRefreshTask, 30 min)
/// - io.sui.widget.cleanup (BGProcessingTask, weekly)
/// - io.sui.widget.coinlist (BGAppRefreshTask, daily)
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // TODO: register background tasks in Phase 1
        return true
    }
}
