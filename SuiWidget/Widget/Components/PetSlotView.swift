import SwiftUI
import SuiWidgetKit

/// V2 pet reservation. V1 renders a dashed-border circle with an egg glyph and "Hatch a pet"
/// label. Tap deep-links to suiwidget://pet/hatch which the app routes to a "Coming soon"
/// screen (added in Task 14).
public struct PetSlotView: View {
    public init() {}

    public var body: some View {
        ZStack {
            Circle()
                .strokeBorder(SuiColor.flat.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
            Text("🥚").font(.system(size: 14))
        }
        .frame(width: 28, height: 28)
        .widgetURL(URL(string: "suiwidget://pet/hatch"))
        .accessibilityLabel("Hatch a pet — coming soon")
    }
}
