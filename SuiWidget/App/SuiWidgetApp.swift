import SwiftUI
import SwiftData
import UIKit
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

    init() {
        #if DEBUG
        // VT323 is bundled via UIAppFonts in Info.plist. If it failed to register,
        // SwiftUI silently falls back to system font — that hides a real bug.
        if UIFont(name: "VT323-Regular", size: 12) == nil {
            print("[SuiWidgetApp] WARNING: VT323-Regular font not loaded. Check UIAppFonts in Info.plist.")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(modelContainer)
        }
    }
}
