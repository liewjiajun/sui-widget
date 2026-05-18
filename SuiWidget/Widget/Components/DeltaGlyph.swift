import SwiftUI
import SuiWidgetKit

/// Renders a ▲/▼/~ glyph + percent label. Uses font weight + color (color skipped on
/// Lock Screen widgets — pass useColor: false).
public struct DeltaGlyph: View {
    public let percent: Double
    public let useColor: Bool
    public let size: CGFloat

    public init(percent: Double, useColor: Bool = true, size: CGFloat = 11) {
        self.percent = percent
        self.useColor = useColor
        self.size = size
    }

    public var body: some View {
        HStack(spacing: 2) {
            Text(glyph).font(SuiTypography.display(size, weight: .bold))
            Text(String(format: "%.1f%%", abs(percent)))
                .font(SuiTypography.mono(size, weight: .bold))
        }
        .foregroundStyle(useColor ? color : Color.primary)
    }

    private var glyph: String {
        if percent > 0.05 { return "▲" }
        if percent < -0.05 { return "▼" }
        return "~"
    }

    private var color: Color {
        if percent > 0.05 { return SuiColor.up }
        if percent < -0.05 { return SuiColor.down }
        return SuiColor.flat
    }
}
