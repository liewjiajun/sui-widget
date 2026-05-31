import Foundation
import SwiftData
import Observation
import SwiftUI
import WidgetKit
import SuiWidgetKit

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum DefaultCurrency: String, CaseIterable, Identifiable {
    case usd, sgd, eur, jpy, krw, cny
    var id: String { rawValue }
    var displayName: String { rawValue.uppercased() }
}

enum AppRefreshFrequency: String, CaseIterable, Identifiable {
    case auto, fifteen = "15", thirty = "30", sixty = "60"
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .fifteen: return "Every 15 minutes"
        case .thirty: return "Every 30 minutes"
        case .sixty: return "Every hour"
        }
    }
}

@MainActor
@Observable
final class SettingsViewModel {
    var theme: AppTheme = .system
    var defaultCurrency: DefaultCurrency = .usd
    var showUntrackedTokens: Bool = true
    var refreshFrequency: AppRefreshFrequency = .auto
    var notificationsEnabled: Bool = false
    var cacheBytes: Int64 = 0
    var clearedCacheConfirmation: Bool = false
    var didReset: Bool = false

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        load()
        computeCacheSize()
    }

    func load() {
        // Singleton row shared with every other context (widget, background).
        let settings = AppSettings.current(in: modelContext)
        theme = AppTheme(rawValue: settings.theme) ?? .system
        defaultCurrency = DefaultCurrency(rawValue: settings.defaultCurrency.lowercased()) ?? .usd
        showUntrackedTokens = settings.showUntrackedTokens
        refreshFrequency = AppRefreshFrequency(rawValue: "\(settings.refreshFrequencyMinutes)") ?? .auto
        notificationsEnabled = settings.notificationsEnabled
    }

    func save() {
        let settings = AppSettings.current(in: modelContext)
        let previousMinutes = settings.refreshFrequencyMinutes
        settings.theme = theme.rawValue
        settings.defaultCurrency = defaultCurrency.rawValue.uppercased()
        settings.showUntrackedTokens = showUntrackedTokens
        switch refreshFrequency {
        case .auto, .fifteen: settings.refreshFrequencyMinutes = 15
        case .thirty: settings.refreshFrequencyMinutes = 30
        case .sixty: settings.refreshFrequencyMinutes = 60
        }
        settings.notificationsEnabled = notificationsEnabled
        try? modelContext.save()

        // Notify foreground observers (e.g. PortfolioViewModel) so the new
        // refresh cadence takes effect immediately without an app restart.
        if previousMinutes != settings.refreshFrequencyMinutes {
            NotificationCenter.default.post(name: .suiWidgetRefreshFrequencyChanged, object: nil)
        }

        // Currency/theme/etc. changed in the shared AppSettings row — force the
        // Home/Lock widgets to re-render now instead of waiting for an unrelated refresh.
        WidgetCenter.shared.reloadAllTimelines()
    }

    func computeCacheSize() {
        let groupId = AppGroupStore.groupIdentifier
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId),
              let enumerator = FileManager.default.enumerator(at: container, includingPropertiesForKeys: [.fileSizeKey]) else {
            cacheBytes = 0
            return
        }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            if let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                total += Int64(size)
            }
        }
        cacheBytes = total
    }

    var cacheBytesLabel: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: cacheBytes)
    }

    func clearCache() {
        let groupId = AppGroupStore.groupIdentifier
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId) else { return }
        let thumbnailsDir = container.appendingPathComponent("Thumbnails", isDirectory: true)
        try? FileManager.default.removeItem(at: thumbnailsDir)
        computeCacheSize()
        clearedCacheConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.clearedCacheConfirmation = false
        }
    }

    func resetEverything() async {
        // Delete every @Model row.
        let entityTypes: [any PersistentModel.Type] = [
            Wallet.self,
            CachedPortfolio.self,
            CachedTokenHolding.self,
            CachedStakePosition.self,
            CachedNFTItem.self,
            CachedNewsItem.self,
            CachedValidatorMetadata.self,
            CachedCoinListEntry.self,
            CachedSuiNSResolution.self,
            ActivityEvent.self,
            AppSettings.self,
        ]
        for type in entityTypes {
            try? modelContext.delete(model: type)
        }
        try? modelContext.save()
        clearCache()
        // Reset @AppStorage flags so onboarding re-fires.
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        didReset = true
    }
}
