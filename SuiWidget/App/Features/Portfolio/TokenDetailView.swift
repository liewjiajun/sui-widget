import SwiftUI
import SuiWidgetKit

struct TokenDetailView: View {
    let holding: CachedTokenHolding

    var body: some View {
        ScrollView {
            VStack(spacing: SuiSpacing.s4) {
                Text(holding.symbol).font(SuiTypography.display(36))
                Text(holding.name).font(SuiTypography.body(14)).foregroundStyle(.secondary)
                Text("Balance: \(decimalString(holding.balance)) \(holding.symbol)")
                    .font(SuiTypography.mono(13))
                Text("Coin type: \(holding.coinType)")
                    .font(SuiTypography.mono(11))
                    .foregroundStyle(.secondary)
                if let price = holding.priceUSD {
                    Text("Price: $\(decimalString(price))")
                        .font(SuiTypography.display(20))
                }
                Spacer()
                Text("Price chart + history coming in V1.1")
                    .font(SuiTypography.body(12))
                    .foregroundStyle(.secondary)
                    .padding(.top, SuiSpacing.s5)
            }
            .padding()
        }
        .navigationTitle(holding.symbol)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func decimalString(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 6
        return formatter.string(from: value as NSDecimalNumber) ?? "0"
    }
}
