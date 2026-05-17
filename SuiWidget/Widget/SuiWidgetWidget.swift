import WidgetKit
import SwiftUI
import SuiWidgetKit

struct SuiWidgetWidget: Widget {
    let kind = "SuiWidgetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HandshakeTimelineProvider()) { entry in
            HandshakeWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Sui Handshake")
        .description("Phase 0 placeholder — shows the value written by the app.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct HandshakeWidgetView: View {
    let entry: HandshakeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sui Widget")
                .font(.caption)
                .bold()
            Text(entry.handshakeValue)
                .font(.caption2)
                .monospaced()
                .lineLimit(3)
            Spacer()
            Text(entry.date, style: .time)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
