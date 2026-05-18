import Foundation

public extension Notification.Name {
    /// Posted by `SettingsViewModel.save()` when `AppSettings.refreshFrequencyMinutes`
    /// actually changes value. Foreground observers (e.g. `PortfolioViewModel`)
    /// listen and reschedule their refresh timers so the new cadence takes
    /// effect immediately without restarting the app.
    static let suiWidgetRefreshFrequencyChanged = Notification.Name("io.sui.widget.refreshFrequencyChanged")
}
