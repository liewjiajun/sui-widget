import SwiftUI
import SuiWidgetKit

struct TokenRowView: View {
    let holding: CachedTokenHolding
    let sliceColor: Color?

    var body: some View {
        HStack(spacing: SuiSpacing.s3) {
            ZStack {
                Circle()
                    .fill((sliceColor ?? SuiColor.flat).opacity(0.18))
                Text(initial)
                    .font(SuiTypography.display(13))
                    .foregroundStyle(sliceColor ?? SuiColor.flat)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(holding.symbol)
                    .font(SuiTypography.body(14, weight: .semibold))
                Text(formattedBalance)
                    .font(SuiTypography.mono(10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(usdLabel)
                    .font(SuiTypography.display(13))
                if let change = holding.priceChange24h {
                    HStack(spacing: 2) {
                        Text(change >= 0 ? "▲" : "▼")
                        Text(String(format: "%.1f%%", abs(change)))
                    }
                    .font(SuiTypography.mono(10, weight: .bold))
                    .foregroundStyle(change >= 0 ? SuiColor.up : SuiColor.down)
                }
            }
            if !holding.isTracked {
                Text("untracked")
                    .font(SuiTypography.mono(8, weight: .bold))
                    .padding(.horizontal, SuiSpacing.s1)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(SuiColor.flat.opacity(0.18)))
                    .foregroundStyle(SuiColor.flat)
            }
        }
        .padding(.vertical, SuiSpacing.s2)
    }

    private var initial: String {
        holding.symbol.first.map { String($0).uppercased() } ?? "?"
    }

    private var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        let balStr = formatter.string(from: holding.balance as NSDecimalNumber) ?? "0"
        return "\(balStr) \(holding.symbol)"
    }

    private var usdLabel: String {
        guard let price = holding.priceUSD else { return "—" }
        let value = price * holding.balance
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}
