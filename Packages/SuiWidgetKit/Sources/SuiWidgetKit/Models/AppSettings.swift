import Foundation
import SwiftData

@Model
public final class AppSettings {
    public var defaultCurrency: String
    public var theme: String
    public var refreshFrequencyMinutes: Int
    public var showUntrackedTokens: Bool
    public var notificationsEnabled: Bool

    public init(
        defaultCurrency: String = "USD",
        theme: String = "system",
        refreshFrequencyMinutes: Int = 30,
        showUntrackedTokens: Bool = true,
        notificationsEnabled: Bool = false
    ) {
        self.defaultCurrency = defaultCurrency
        self.theme = theme
        self.refreshFrequencyMinutes = refreshFrequencyMinutes
        self.showUntrackedTokens = showUntrackedTokens
        self.notificationsEnabled = notificationsEnabled
    }
}
