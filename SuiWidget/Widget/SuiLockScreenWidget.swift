import SwiftUI
import WidgetKit
import SuiWidgetKit

public struct SuiLockScreenWidget: Widget {
    public init() {}
    public let kind = "SuiLockScreenWidget"

    public var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SuiWidgetConfigurationIntent.self,
            provider: SuiTimelineProvider()
        ) { entry in
            LockScreenEntryView(entry: entry)
        }
        .configurationDisplayName("Sui Lock Screen")
        .description("Portfolio value and 24h delta on the Lock Screen.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

private struct LockScreenEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: SuiWidgetEntry

    var body: some View {
        switch family {
        case .accessoryInline: InlineWidgetView(entry: entry)
        case .accessoryCircular: CircularWidgetView(entry: entry)
        case .accessoryRectangular: RectangularWidgetView(entry: entry)
        default: Text("Unsupported")
        }
    }
}
