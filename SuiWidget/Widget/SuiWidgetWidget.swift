import SwiftUI
import WidgetKit
import SuiWidgetKit

public struct SuiWidgetWidget: Widget {
    public init() {}

    public let kind = "SuiWidgetWidget"

    public var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SuiWidgetConfigurationIntent.self,
            provider: SuiTimelineProvider()
        ) { entry in
            SuiWidgetEntryView(entry: entry)
                // Neutral system background so HomeWidgetChrome's tinted gradient
                // composites identically in light + dark mode. Lock Screen
                // widgets ignore this — iOS tints them monochrome.
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
        }
        .configurationDisplayName("Sui Portfolio")
        .description("Portfolio value, top tokens, NFTs, news and staking.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

private struct SuiWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: SuiWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall: SmallWidgetView(entry: entry)
        case .systemMedium: MediumWidgetView(entry: entry)
        case .systemLarge: LargeWidgetView(entry: entry)
        case .systemExtraLarge: ExtraLargeWidgetView(entry: entry)
        default:
            Text("Unsupported widget family")
                .font(SuiTypography.body(11))
        }
    }
}
