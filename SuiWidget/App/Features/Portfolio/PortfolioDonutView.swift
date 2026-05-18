import SwiftUI
import SuiWidgetKit

/// Pixel-style donut chart showing token-mix by USD value.
/// Uses Canvas with arc segments; center shows total USD.
struct PortfolioDonutView: View {
    struct Slice: Identifiable {
        let id = UUID()
        let label: String
        let value: Decimal
        let color: Color
    }

    let slices: [Slice]
    let totalUSD: Decimal

    private static let palette: [Color] = [
        SuiColor.suiBlue,
        SuiColor.suiDeep,
        SuiColor.up,
        SuiColor.amber,
        SuiColor.coral,
    ]

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 * 0.92
                let lineWidth: CGFloat = radius * 0.38

                let total = slices.reduce(Decimal(0)) { $0 + $1.value }
                guard total > 0 else {
                    let path = Path { $0.addArc(center: center, radius: radius - lineWidth / 2,
                                                  startAngle: .zero, endAngle: .degrees(360), clockwise: false) }
                    context.stroke(path, with: .color(SuiColor.flat.opacity(0.18)),
                                   style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    return
                }

                var startAngle: Angle = .degrees(-90)
                for slice in slices {
                    let fraction = Double(truncating: (slice.value / total) as NSNumber)
                    let endAngle = startAngle + .degrees(360 * fraction)
                    let path = Path { p in
                        p.addArc(center: center, radius: radius - lineWidth / 2,
                                  startAngle: startAngle, endAngle: endAngle, clockwise: false)
                    }
                    context.stroke(path, with: .color(slice.color),
                                   style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    startAngle = endAngle
                }
            }
            VStack(spacing: 2) {
                Text("TOTAL")
                    .font(SuiTypography.mono(9, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(usdLabel)
                    .font(SuiTypography.display(20))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(width: 140, height: 140)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Portfolio total \(usdLabel), split across \(slices.count) tokens")
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
