import SwiftUI
import SuiWidgetKit

/// Pixel-style donut chart showing token-mix by USD value.
/// Slices stroke in with a per-segment 60ms stagger on appear; center shows total USD.
struct PortfolioDonutView: View {
    struct Slice: Identifiable {
        let id = UUID()
        let label: String
        let value: Decimal
        let color: Color
    }

    let slices: [Slice]
    let totalUSD: Decimal
    @State private var animationProgress: Double = 0

    private static let palette: [Color] = [
        SuiColor.suiBlue,
        SuiColor.suiDeep,
        SuiColor.up,
        SuiColor.amber,
        SuiColor.coral,
    ]

    var body: some View {
        ZStack {
            // Empty-state ring drawn underneath; slices overlay it as they stroke in.
            Circle()
                .stroke(SuiColor.flat.opacity(0.18), style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .butt))
                .padding(ringLineWidth / 2)
                .opacity(slices.isEmpty ? 1 : 0)

            ForEach(slices.indices, id: \.self) { idx in
                ArcSliceShape(
                    startFraction: cumulativeStartFraction(at: idx),
                    endFraction: cumulativeEndFraction(at: idx)
                )
                .trim(from: 0, to: trimEnd(forSliceIndex: idx, progress: animationProgress))
                .stroke(slices[idx].color, style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .butt))
            }

            VStack(spacing: 2) {
                Text("TOTAL")
                    .font(SuiTypography.mono(9, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(usdLabel)
                    .font(SuiTypography.pixelDisplay(32))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
            }
        }
        .frame(width: 140, height: 140)
        .onAppear {
            animationProgress = 0
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                animationProgress = 1.0
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Portfolio total \(usdLabel), split across \(slices.count) tokens")
    }

    /// 140 × 0.92 / 2 = 64.4 radius, line width 0.38 of radius ~= 24.4pt — matches the
    /// previous Canvas-rendered ring exactly.
    private var ringLineWidth: CGFloat {
        let radius = 140 / 2 * 0.92
        return radius * 0.38
    }

    /// Stagger: each slice's draw begins at idx × 0.15 of the overall timeline
    /// (~60ms per slice when the spring resolves in ~400ms).
    private func trimEnd(forSliceIndex idx: Int, progress: Double) -> Double {
        let staggerStart = Double(idx) * 0.15
        guard staggerStart < 1 else { return 0 }
        let local = (progress - staggerStart) / (1.0 - staggerStart)
        return max(0, min(1, local))
    }

    private func cumulativeStartFraction(at idx: Int) -> Double {
        let total = slices.reduce(Decimal(0)) { $0 + $1.value }
        guard total > 0, idx > 0 else { return 0 }
        return slices.prefix(idx).reduce(0.0) { sum, slice in
            sum + Double(truncating: (slice.value / total) as NSNumber)
        }
    }

    private func cumulativeEndFraction(at idx: Int) -> Double {
        let total = slices.reduce(Decimal(0)) { $0 + $1.value }
        guard total > 0 else { return 0 }
        return slices.prefix(idx + 1).reduce(0.0) { sum, slice in
            sum + Double(truncating: (slice.value / total) as NSNumber)
        }
    }

    private var usdLabel: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: totalUSD as NSDecimalNumber) ?? "$0"
    }

    /// Helper that builds slices from a CachedPortfolio.
    static func slices(from portfolio: CachedPortfolio) -> [Slice] {
        slices(fromTokens: portfolio.tokens)
    }

    /// Helper for building slices from any token list — used by the "All
    /// wallets" aggregate which doesn't have a backing CachedPortfolio.
    static func slices(fromTokens tokens: [CachedTokenHolding]) -> [Slice] {
        let tracked = tokens.filter { $0.isTracked && ($0.priceUSD ?? 0) > 0 }
        return tracked.enumerated().map { idx, holding in
            let value = (holding.priceUSD ?? 0) * holding.balance
            return Slice(
                label: holding.symbol,
                value: value,
                color: Self.palette[idx % Self.palette.count]
            )
        }
    }
}

/// Single arc segment used by PortfolioDonutView. `.trim(from:to:)` animates the
/// stroke length so a slice draws itself on appear.
private struct ArcSliceShape: Shape {
    let startFraction: Double
    let endFraction: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 * 0.92
        let lineWidth: CGFloat = radius * 0.38

        var path = Path()
        path.addArc(
            center: center,
            radius: radius - lineWidth / 2,
            startAngle: .degrees(-90 + 360 * startFraction),
            endAngle: .degrees(-90 + 360 * endFraction),
            clockwise: false
        )
        return path
    }
}
