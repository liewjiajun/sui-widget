import SwiftUI

/// Tiny synthetic sparkline rendered as a chunky pixel line.
/// V1 uses a placeholder linear ramp informed by the 24h delta sign — real price-history
/// sparklines land in V1.1 when the data layer caches an hourly price history.
public struct PixelSparkline: View {
    public let trend: Double  // -1.0 to 1.0; positive = upward
    public let color: Color
    public let pixelSize: CGFloat

    public init(trend: Double, color: Color, pixelSize: CGFloat = 3) {
        self.trend = trend.clamped(to: -1...1)
        self.color = color
        self.pixelSize = pixelSize
    }

    public var body: some View {
        Canvas { context, size in
            let columns = max(2, Int(size.width / pixelSize))
            let rows = max(2, Int(size.height / pixelSize))
            // Synthetic curve: half-sine for a smooth trend, optionally inverted.
            for col in 0..<columns {
                let t = Double(col) / Double(columns - 1)
                let curve = sin(t * .pi * 0.6) * trend  // [-1, 1] when trend = 1
                let y = (1 - (curve + 1) / 2) * Double(rows - 1)
                let row = Int(y.rounded())
                let rect = CGRect(
                    x: CGFloat(col) * pixelSize,
                    y: CGFloat(row) * pixelSize,
                    width: pixelSize,
                    height: pixelSize
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        max(range.lowerBound, min(range.upperBound, self))
    }
}
