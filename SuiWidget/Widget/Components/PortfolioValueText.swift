import SwiftUI
import SuiWidgetKit

public struct PortfolioValueText: View {
    public let value: Decimal
    public let currencySymbol: String
    public let size: CGFloat

    public init(value: Decimal, currencySymbol: String = "$", size: CGFloat) {
        self.value = value
        self.currencySymbol = currencySymbol
        self.size = size
    }

    public var body: some View {
        Text(formatted)
            .font(SuiTypography.display(size, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityLabel("Portfolio total \(formatted)")
    }

    private var formatted: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = value > 10_000 ? 0 : 2
        f.minimumFractionDigits = value > 10_000 ? 0 : 2
        let str = f.string(from: value as NSDecimalNumber) ?? "0"
        return "\(currencySymbol)\(str)"
    }
}
