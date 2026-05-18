import SwiftUI
import SwiftData
import SuiWidgetKit

@main
struct SuiWidgetApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let modelContainer: ModelContainer = {
        do {
            return try SwiftDataStack.makeContainer()
        } catch {
            // Fall back to in-memory if production container fails (e.g. running in a non-entitled context).
            // Logged so we notice in production.
            print("[SuiWidgetApp] Falling back to in-memory ModelContainer: \(error)")
            return try! SwiftDataStack.makeContainer(inMemory: true)
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(modelContainer)
        }
    }
}
