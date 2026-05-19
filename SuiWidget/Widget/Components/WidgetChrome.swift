import SwiftUI
import WidgetKit
import SuiWidgetKit

/// Sui-blue gradient + pixel-droplet watermark + top accent stripe used as the
/// `containerBackground` for every Home Screen widget. Rendering this via the
/// container background (rather than as a ZStack sibling to the content) is
/// what makes the chrome fill the full widget rect — including the padded
/// content's outer 10pt — instead of sizing to the content alone.
public struct HomeWidgetBackground: View {
    public let watermarkSize: CGFloat

    public init(watermarkSize: CGFloat) {
        self.watermarkSize = watermarkSize
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    SuiColor.suiTint.opacity(0.30),
                    SuiColor.suiPale.opacity(0.45),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Watermark — pixel droplet bleeding into the bottom-right corner.
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    SuiGlyph(size: watermarkSize, fill: SuiColor.suiBlue.opacity(0.10))
                        .offset(x: watermarkSize * 0.20, y: watermarkSize * 0.20)
                }
            }

            // Top pixel-accent stripe — 24 alternating-opacity 3pt rectangles.
            // Rendered against the widget's actual top edge thanks to
            // containerBackground, not the padded content area.
            HStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { idx in
                    Rectangle()
                        .fill(SuiColor.suiBlue.opacity(idx % 2 == 0 ? 0.55 : 0.25))
                        .frame(height: 3)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: 3, alignment: .top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

public extension View {
    /// Applies the Home Screen chrome to the widget rect. Internally this sets
    /// `containerBackground(for: .widget)` — WidgetKit requires every widget to
    /// install a container background, and that's also the only modifier that
    /// reliably fills the widget's full bounds (including past the content's
    /// padding) on iOS 17+.
    func homeWidgetChrome(watermarkSize: CGFloat) -> some View {
        containerBackground(for: .widget) {
            HomeWidgetBackground(watermarkSize: watermarkSize)
        }
    }
}
