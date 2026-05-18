import SwiftUI

/// Chunky pixel-art SUI water-droplet glyph rendered procedurally as a SwiftUI View.
/// Sized via the `size` parameter (the glyph fits in a `size × size` square).
/// Default fill is `SuiColor.suiBlue`; pass a different fill for tinted contexts (lock screen).
public struct SuiGlyph: View {
    public let size: CGFloat
    public let fill: Color

    public init(size: CGFloat = 16, fill: Color = SuiColor.suiBlue) {
        self.size = size
        self.fill = fill
    }

    /// 16x16 pixel grid. 1 = filled, 0 = empty.
    /// Droplet body — bell-curve top tapering to a wide rounded base. The eye + mouth pixels
    /// are highlights/shadows, drawn separately for the AppIcon variant but for the inline
    /// glyph we stay solid.
    private static let pixels: [[Int]] = [
        [0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0],
        [0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0],
        [0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0],
        [0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0],
        [0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0],
        [0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0],
        [0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0],
        [0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0],
        [0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0],
        [0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0],
        [0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0],
    ]

    public var body: some View {
        Canvas { context, canvasSize in
            let pixel = canvasSize.width / 16
            for (y, row) in Self.pixels.enumerated() {
                for (x, on) in row.enumerated() where on == 1 {
                    let rect = CGRect(
                        x: CGFloat(x) * pixel,
                        y: CGFloat(y) * pixel,
                        width: pixel,
                        height: pixel
                    )
                    context.fill(Path(rect), with: .color(fill))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
