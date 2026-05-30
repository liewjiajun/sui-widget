import Foundation
import SwiftData

@Model
public final class AppSettings {
    @Attribute(.unique) public var singletonKey: String
    public var defaultCurrency: String
    public var theme: String
    public var refreshFrequencyMinutes: Int
    public var showUntrackedTokens: Bool
    public var notificationsEnabled: Bool
    public var lastCoinListFetchedAt: Date?
    public var lastNewsFetchedAt: Date?

    public init(
        singletonKey: String = "default",
        defaultCurrency: String = "USD",
        theme: String = "system",
        refreshFrequencyMinutes: Int = 30,
        showUntrackedTokens: Bool = true,
        notificationsEnabled: Bool = false,
        lastCoinListFetchedAt: Date? = nil,
        lastNewsFetchedAt: Date? = nil
    ) {
        self.singletonKey = singletonKey
        self.defaultCurrency = defaultCurrency
        self.theme = theme
        self.refreshFrequencyMinutes = refreshFrequencyMinutes
        self.showUntrackedTokens = showUntrackedTokens
        self.notificationsEnabled = notificationsEnabled
        self.lastCoinListFetchedAt = lastCoinListFetchedAt
        self.lastNewsFetchedAt = lastNewsFetchedAt
    }

    /// The single shared settings row, creating it if absent. All callers should
    /// route through this so app / widget / background contexts converge on the
    /// one `.unique singletonKey` row even though each opens its own
    /// `ModelContext` against the App Group store.
    public static func current(in context: ModelContext) -> AppSettings {
        if let existing = try? context.fetch(FetchDescriptor<AppSettings>()).first {
            return existing
        }
        let created = AppSettings()
        context.insert(created)
        try? context.save()
        return created
    }
}
