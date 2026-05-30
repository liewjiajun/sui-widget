import SwiftUI
import SuiWidgetKit

public struct PortfolioValueText: View {
    /// USD-denominated value. Converted to `currency` for display via
    /// `WidgetCurrencyFormatter` (with a USD fallback when no FX rate is cached).
    public let value: Decimal
    public let currency: CurrencyOption
    public let size: CGFloat

    public init(value: Decimal, currency: CurrencyOption = .usd, size: CGFloat) {
        self.value = value
        self.currency = currency
        self.size = size
    }

    public var body: some View {
        Text(formatted)
            .font(SuiTypography.pixelDisplay(size))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText())
            .accessibilityLabel("Portfolio total \(formatted)")
    }

    private var formatted: String {
        let (effective, converted) = WidgetCurrencyFormatter.resolve(usdValue: value, currency: currency)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = converted > 10_000 ? 0 : 2
        f.minimumFractionDigits = converted > 10_000 ? 0 : 2
        let str = f.string(from: converted as NSDecimalNumber) ?? "0"
        return "\(effective.symbol)\(str)"
    }
}
