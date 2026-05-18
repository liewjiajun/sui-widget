import SwiftUI

/// Tiny pixel-stepped sparkline. Takes a series of points (e.g. hourly prices)
/// and renders them as chunky pixels. If `points` is empty or has fewer than
/// 2 values, falls back to a flat baseline.
public struct PixelSparkline: View {
    public let points: [Double]
    public let color: Color
    public let pixelSize: CGFloat

    public init(points: [Double], color: Color, pixelSize: CGFloat = 3) {
        self.points = points
        self.color = color
        self.pixelSize = pixelSize
    }

    public var body: some View {
        Canvas { context, size in
            let columns = max(2, Int(size.width / pixelSize))
            let rows = max(2, Int(size.height / pixelSize))

            guard points.count >= 2 else {
                renderFlat(context: context, size: size, columns: columns, rows: rows)
                return
            }

            // Resample input series into `columns` buckets (avg).
            let resampled = resample(points: points, columns: columns)
            let minVal = resampled.min() ?? 0
            let maxVal = resampled.max() ?? 1
            let range = max(maxVal - minVal, 0.0001)

            for (col, value) in resampled.enumerated() {
                let normalized = (value - minVal) / range  // 0...1
                let pixelRow = (1 - normalized) * Double(rows - 1)
                let row = Int(pixelRow.rounded())
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

    private func resample(points: [Double], columns: Int) -> [Double] {
        guard !points.isEmpty else { return Array(repeating: 0, count: columns) }
        if points.count == columns { return points }
        // Linear-interp resample.
        var out: [Double] = []
        out.reserveCapacity(columns)
        for col in 0..<columns {
            let t = Double(col) / Double(columns - 1)
            let sourceIndex = t * Double(points.count - 1)
            let lo = Int(sourceIndex)
            let hi = min(lo + 1, points.count - 1)
            let frac = sourceIndex - Double(lo)
            out.append(points[lo] * (1 - frac) + points[hi] * frac)
        }
        return out
    }

    private func renderFlat(context: GraphicsContext, size: CGSize, columns: Int, rows: Int) {
        let midRow = rows / 2
        for col in 0..<columns {
            let rect = CGRect(
                x: CGFloat(col) * pixelSize,
                y: CGFloat(midRow) * pixelSize,
                width: pixelSize,
                height: pixelSize
            )
            context.fill(Path(rect), with: .color(color.opacity(0.5)))
        }
    }
}
