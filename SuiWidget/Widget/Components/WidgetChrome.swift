import SwiftUI
import SuiWidgetKit

/// Visual chrome applied to every Home Screen widget — Sui-blue tinted background,
/// a faint pixel-droplet watermark in the bottom-right corner, and a pixel accent
/// stripe across the top.
///
/// Lock Screen widgets MUST stay monochrome per iOS (the OS tints them to the
/// system accent) — they deliberately do NOT use this modifier.
public struct HomeWidgetChrome: ViewModifier {
    let watermarkSize: CGFloat

    public init(watermarkSize: CGFloat) {
        self.watermarkSize = watermarkSize
    }

    public func body(content: Content) -> some View {
        ZStack(alignment: .topLeading) {
            // Tinted background gradient — sits on the system background so it
            // reads identically in light + dark mode.
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

            // Top pixel-accent stripe — 24 alternating-opacity 3pt rectangles
            // forming a subtle pixel-art brand mark across the very top edge.
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

            // Foreground widget content.
            content
        }
    }
}

public extension View {
    /// Applies the Home Screen widget chrome. Pass a `watermarkSize` tuned to
    /// the widget family (32 small / 48 medium / 64 large / 72 XL).
    func homeWidgetChrome(watermarkSize: CGFloat) -> some View {
        modifier(HomeWidgetChrome(watermarkSize: watermarkSize))
    }
}
